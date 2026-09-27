import AppKit
import AVFoundation
import CoreGraphics
import os

/// `log stream --predicate 'subsystem == "com.pratikaman.thock"'` to watch it live.
let log = Logger(subsystem: "com.pratikaman.thock", category: "engine")

enum ClipError: LocalizedError {
    case unreadable, silent

    var errorDescription: String? {
        switch self {
        case .unreadable: "Thock couldn't read that audio file."
        case .silent: "That file seems to be silent."
        }
    }
}

/// Turns any audio file into a punchy keystroke clip: mono 48 kHz, leading silence cut,
/// peak-normalized, and capped at `maxSeconds` with a fade so long files don't drag.
enum Clip {
    static let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    static let maxSeconds = 2.0

    static func load(_ url: URL) throws -> AVAudioPCMBuffer {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { throw ClipError.unreadable }
        let src = file.processingFormat
        // Read a little past the cap so a quiet lead-in doesn't eat the whole clip.
        let frames = AVAudioFrameCount(min(file.length, AVAudioFramePosition(src.sampleRate * (maxSeconds + 3))))
        let outFrames = AVAudioFrameCount(Double(frames) * format.sampleRate / src.sampleRate) + 4096
        guard let input = AVAudioPCMBuffer(pcmFormat: src, frameCapacity: frames),
              (try? file.read(into: input, frameCount: frames)) != nil,
              let converter = AVAudioConverter(from: src, to: format),
              let decoded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outFrames)
        else { throw ClipError.unreadable }

        converter.downmix = true
        var fed = false
        var error: NSError?
        converter.convert(to: decoded, error: &error) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return input
        }
        guard error == nil else { throw ClipError.unreadable }
        return try shape(decoded)
    }

    private static func shape(_ b: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let x = b.floatChannelData![0], n = Int(b.frameLength)
        var peak: Float = 0
        for i in 0..<n { peak = max(peak, abs(x[i])) }
        guard peak > 0.001, let onset = (0..<n).first(where: { abs(x[$0]) >= peak * 0.1 }) else { throw ClipError.silent }

        let start = max(0, onset - 48)                  // keep 1 ms before the attack
        let cap = Int(format.sampleRate * maxSeconds)
        let len = min(n - start, cap)
        let fade = min(len, n - start > cap ? 7_200 : 480)  // 150 ms if we cut it short, else 10 ms
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(len))!
        out.frameLength = AVAudioFrameCount(len)
        let y = out.floatChannelData![0], gain = 0.9 / peak
        for i in 0..<len {
            let tail = len - i
            y[i] = x[start + i] * gain * (tail < fade ? Float(tail) / Float(fade) : 1)
        }
        return out
    }
}

/// A small pool of voices so fast typing overlaps instead of cutting itself off.
final class Player {
    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var next = 0
    private var current: AVAudioPCMBuffer?
    /// Every engine call runs here, never on the key-tap thread: while the output device is
    /// switching, `engine.start()` can block for a long time, and macOS drops keys for a stalled tap.
    private let queue = DispatchQueue(label: "Thock audio", qos: .userInteractive)

    var buffer: AVAudioPCMBuffer? {
        get { queue.sync { current } }
        set { queue.async { self.current = newValue } }
    }

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    init() {
        for _ in 0..<12 {
            let v = AVAudioPlayerNode()
            engine.attach(v)
            engine.connect(v, to: engine.mainMixerNode, format: Clip.format)
            voices.append(v)
        }
        // Switching outputs (AirPods, speakers, a mic turning on) stops the engine, so bring it back.
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            log.info("audio configuration changed, restarting")
            self?.start()
        }
    }

    func start() { queue.async { self.restart(attempt: 0) } }
    func pause() { queue.async { self.engine.pause() } }

    /// Called from the key-tap thread and from the UI; returns immediately.
    func play(_ clip: AVAudioPCMBuffer? = nil) {
        queue.async { [self] in
            guard let clip = clip ?? current else { return }
            if !engine.isRunning { restart(attempt: 0) }
            guard engine.isRunning else { return }
            let v = voices[next]
            next = (next + 1) % voices.count
            if !v.isPlaying { v.play() }
            v.scheduleBuffer(clip, at: nil, options: .interrupts)
        }
    }

    /// A device mid-switch can refuse to start, so keep trying for a couple of seconds.
    private func restart(attempt: Int) {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            voices.forEach { $0.play() }
            if attempt > 0 { log.info("audio engine started after \(attempt) retries") }
        } catch {
            log.error("audio engine failed to start (attempt \(attempt)): \(error.localizedDescription, privacy: .public)")
            if attempt < 10 { queue.asyncAfter(deadline: .now() + 0.25) { self.restart(attempt: attempt + 1) } }
        }
    }
}

/// Listen-only CGEvent tap on its own thread, so a busy UI never delays a click.
/// Needs Input Monitoring permission; it only sees *that* a key went down, and it
/// never modifies or blocks events.
final class KeyTap {
    var onPress: (() -> Void)?
    var active = true
    var includeModifiers = true
    var includeRepeats = false
    private var tap: CFMachPort?

    private static let modifierMasks: [Int64: CGEventFlags] = [
        56: .maskShift, 60: .maskShift, 59: .maskControl, 62: .maskControl,
        58: .maskAlternate, 61: .maskAlternate, 55: .maskCommand, 54: .maskCommand,
        63: .maskSecondaryFn, 57: .maskAlphaShift,
    ]

    /// Should this event make a sound? Modifiers only count on the way down.
    static func plays(_ type: CGEventType, keyCode: Int64, flags: CGEventFlags, isRepeat: Bool, modifiers: Bool, repeats: Bool) -> Bool {
        switch type {
        case .keyDown:
            return repeats || !isRepeat
        case .flagsChanged:
            guard modifiers, let mask = modifierMasks[keyCode] else { return false }
            return keyCode == 57 || flags.contains(mask)   // caps lock toggles, so every press counts
        default:
            return false
        }
    }

    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                Unmanaged<KeyTap>.fromOpaque(info!).takeUnretainedValue().handle(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "Thock key tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    /// macOS can switch a tap off without always telling us, so the model checks this every few seconds.
    func ensureEnabled() {
        guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        log.error("key tap was disabled, re-enabling")
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// When a password field or an app turns on Secure Input, macOS hides every key from event taps.
    static func secureInputOwner() -> String? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = session["kCGSSessionSecureInputPID"] as? Int32, pid != 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "another app"
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            log.error("key tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input", privacy: .public), re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard active, Self.plays(
            type,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            modifiers: includeModifiers, repeats: includeRepeats
        ) else { return }
        onPress?()
    }
}

/// `Thock --selftest`: run by build.sh, fails the build if clip shaping or key logic breaks.
enum SelfTest {
    static func run() -> Never {
        func check(_ ok: Bool, _ what: String) {
            if !ok { print("selftest FAIL:", what); exit(1) }
        }
        func peakAndAttack(_ b: AVAudioPCMBuffer) -> (Float, Bool) {
            let x = b.floatChannelData![0], n = Int(b.frameLength)
            let peak = (0..<n).map { abs(x[$0]) }.max() ?? 0
            return (peak, (0..<min(n, 144)).contains { abs(x[$0]) >= 0.09 })
        }

        for s in Presets.classics + Presets.silly {
            guard let b = try? Clip.load(s.url) else { check(false, "load \(s.id)"); continue }
            let (peak, attack) = peakAndAttack(b)
            check(abs(peak - 0.9) < 0.01, "\(s.id) is normalized (peak \(peak))")
            check(attack, "\(s.id) starts on the attack")
        }

        // A custom file: 0.5 s of silence then 3 s of 44.1 kHz stereo tone → trimmed, resampled, capped.
        let tmp = FileManager.default.temporaryDirectory
        func write(_ name: String, tone: Bool) -> URL {
            let url = tmp.appendingPathComponent(name)
            let fmt = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 154_350)!
            buf.frameLength = buf.frameCapacity
            for c in 0..<2 {
                for i in 0..<Int(buf.frameLength) {
                    buf.floatChannelData![c][i] = tone && i >= 22_050 ? 0.3 * sin(Float(i) * 0.06) : 0
                }
            }
            do { let f = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2]); try f.write(from: buf) } catch {
                check(false, "write \(name)")
            }
            return url
        }
        let tone = try? Clip.load(write("thock-tone.caf", tone: true))
        check(tone?.frameLength == 96_000, "long custom sound is capped at 2 s")
        if let tone { check(peakAndAttack(tone).1, "leading silence is trimmed") }
        check((try? Clip.load(write("thock-silent.caf", tone: false))) == nil, "silent file is rejected")

        let key = { (type: CGEventType, code: Int64, flags: CGEventFlags, rep: Bool, mods: Bool, reps: Bool) in
            KeyTap.plays(type, keyCode: code, flags: flags, isRepeat: rep, modifiers: mods, repeats: reps)
        }
        check(key(.keyDown, 0, [], false, true, false), "key press plays")
        check(!key(.keyDown, 0, [], true, true, false), "held key is quiet by default")
        check(key(.keyDown, 0, [], true, true, true), "held key plays with repeats on")
        check(key(.flagsChanged, 56, .maskShift, false, true, false), "shift down plays")
        check(!key(.flagsChanged, 56, [], false, true, false), "shift up is quiet")
        check(!key(.flagsChanged, 56, .maskShift, false, false, false), "modifiers can be switched off")
        check(!key(.flagsChanged, 99, .maskShift, false, true, false), "unknown flag change is ignored")

        print("selftest ok")
        exit(0)
    }
}
