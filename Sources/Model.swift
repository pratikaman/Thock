import AppKit
import AVFoundation
import ServiceManagement

struct Sound: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let emoji: String
    let tint: UInt32
    let url: URL

    var isCustom: Bool { id.hasPrefix("custom:") }
}

/// Clips come from BigSoundBank (CC0-style licence, see README); Bubble is macOS's own Pop.
enum Presets {
    private static func bundled(_ name: String) -> URL {
        Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Sounds")!
    }

    static let classics = [
        Sound(id: "keyboard", name: "Keyboard", blurb: "A soft laptop keystroke", emoji: "⌨️", tint: 0xE9E4DA, url: bundled("keyboard")),
        Sound(id: "typewriter", name: "Typewriter", blurb: "The crisp strike of an old manual", emoji: "🖋️", tint: 0xF3E3C8, url: bundled("typewriter")),
        Sound(id: "pop", name: "Bubble", blurb: "The classic macOS pop", emoji: "🫧", tint: 0xDCEBF5,
              url: URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")),
    ]

    static let silly = [
        Sound(id: "gun", name: "Gunshot", blurb: "A .357 Magnum. Every. Single. Key.", emoji: "🔫", tint: 0xF7CDBA, url: bundled("gun")),
        Sound(id: "meow", name: "Meow", blurb: "One small cat, one meow per key", emoji: "🐱", tint: 0xF0D7FF, url: bundled("meow")),
        Sound(id: "bark", name: "Woof", blurb: "An old dog with opinions", emoji: "🐶", tint: 0xF6DFB4, url: bundled("bark")),
        Sound(id: "quack", name: "Quack", blurb: "A mallard duck, very sincere", emoji: "🦆", tint: 0xDBF6E7, url: bundled("quack")),
    ]
}

final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let customDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thock/Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    let player = Player()
    let tap = KeyTap()
    private let defaults = UserDefaults.standard
    private var clips: [String: AVAudioPCMBuffer] = [:]
    private var retry: Timer?
    private var health: Timer?
    private var day: String
    /// Keeps App Nap from throttling us while the window is hidden; typing sounds are latency-critical.
    private let activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical], reason: "Playing keystroke sounds")

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "enabled"); tap.active = enabled; enabled ? player.start() : player.pause() }
    }
    @Published var selectedID: String {
        didSet { defaults.set(selectedID, forKey: "sound"); player.buffer = clip(for: selected) }
    }
    @Published var volume: Double {
        didSet { defaults.set(volume, forKey: "volume"); player.volume = Float(volume) }
    }
    @Published var modifiers: Bool {
        didSet { defaults.set(modifiers, forKey: "modifiers"); tap.includeModifiers = modifiers }
    }
    @Published var repeats: Bool {
        didSet { defaults.set(repeats, forKey: "repeats"); tap.includeRepeats = repeats }
    }
    @Published var showPill: Bool {
        didSet { defaults.set(showPill, forKey: "pill") }
    }
    @Published private(set) var openAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var custom: [Sound] = []
    @Published private(set) var listening = false
    /// Name of the app holding Secure Input (password fields do this), which silences every key.
    @Published private(set) var secureInputApp: String?
    @Published private(set) var today: Int
    @Published private(set) var total: Int
    @Published private(set) var pulse = 0

    var allSounds: [Sound] { Presets.classics + Presets.silly + custom }
    var selected: Sound { allSounds.first { $0.id == selectedID } ?? Presets.classics[0] }
    var pillVisible: Bool { showPill && enabled && listening }

    private init() {
        defaults.register(defaults: ["enabled": true, "sound": "keyboard", "volume": 0.7,
                                     "modifiers": true, "repeats": false, "pill": true])
        enabled = defaults.bool(forKey: "enabled")
        selectedID = defaults.string(forKey: "sound")!
        volume = defaults.double(forKey: "volume")
        modifiers = defaults.bool(forKey: "modifiers")
        repeats = defaults.bool(forKey: "repeats")
        showPill = defaults.bool(forKey: "pill")
        day = Self.dayKey()
        today = defaults.string(forKey: "day") == day ? defaults.integer(forKey: "today") : 0
        total = defaults.integer(forKey: "total")

        // didSet doesn't run during init, so push the saved state into the engine by hand.
        tap.active = enabled
        tap.includeModifiers = modifiers
        tap.includeRepeats = repeats
        player.volume = Float(volume)
        refreshCustom()
        if !allSounds.contains(where: { $0.id == selectedID }) { selectedID = "keyboard" }
        player.buffer = clip(for: selected)
        if enabled { player.start() }

        tap.onPress = { [weak self] in
            guard let self else { return }
            player.play()
            DispatchQueue.main.async { self.countKeystroke() }
        }
    }

    // MARK: Sounds

    func select(_ sound: Sound) {
        selectedID = sound.id
        preview(sound)
    }

    func preview(_ sound: Sound) {
        if let c = clip(for: sound) { player.play(c) }
    }

    private func clip(for sound: Sound) -> AVAudioPCMBuffer? {
        if let c = clips[sound.id] { return c }
        let c = try? Clip.load(sound.url)
        clips[sound.id] = c
        return c
    }

    /// Custom sounds are just the files in Application Support/Thock/Sounds.
    func refreshCustom() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.customDir, includingPropertiesForKeys: nil)) ?? []
        custom = files
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Sound(id: "custom:" + $0.lastPathComponent, name: $0.deletingPathExtension().lastPathComponent,
                         blurb: "Your own sound", emoji: "🎵", tint: 0xEDEAE3, url: $0) }
    }

    func importSound(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        _ = try Clip.load(url)   // reject unreadable or silent files before copying anything

        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        var dest = Self.customDir.appendingPathComponent(url.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = Self.customDir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        try FileManager.default.copyItem(at: url, to: dest)
        refreshCustom()
        if let added = custom.first(where: { $0.url.lastPathComponent == dest.lastPathComponent }) { select(added) }
    }

    func remove(_ sound: Sound) {
        try? FileManager.default.removeItem(at: sound.url)
        clips[sound.id] = nil
        refreshCustom()
        if selectedID == sound.id { selectedID = "keyboard" }
    }

    // MARK: Keyboard access

    /// Starts the tap once Input Monitoring is allowed, polling until the user flips the switch.
    func startListening() {
        guard !listening else { return }
        if CGPreflightListenEventAccess(), tap.start() {
            listening = true
            retry?.invalidate()
            retry = nil
            health = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkHealth() }
        } else if retry == nil {
            retry = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.startListening() }
        }
    }

    private func checkHealth() {
        tap.ensureEnabled()
        let owner = KeyTap.secureInputOwner()
        if owner != secureInputApp {
            if let owner { log.info("secure input on in \(owner, privacy: .public), keys are hidden") }
            secureInputApp = owner
        }
    }

    func requestAccess() {
        if !CGRequestListenEventAccess() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
    }

    func setOpenAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Stats

    private func countKeystroke() {
        let now = Self.dayKey()
        if now != day { day = now; today = 0 }
        today += 1
        total += 1
        pulse &+= 1
        defaults.set(today, forKey: "today")
        defaults.set(total, forKey: "total")
        defaults.set(day, forKey: "day")
    }

    private static func dayKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }
}
