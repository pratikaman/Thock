import SwiftUI
import UniformTypeIdentifiers

// MARK: Theme — palette sampled from Wispr Flow's desktop app, same type pairing (EB Garamond + Figtree)

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static let chrome = Color(hex: 0xF7F6F3)
    static let paper = Color(hex: 0xFCFCFB)
    static let well = Color(hex: 0xF4F3EF)
    static let line = Color(hex: 0xE7E5DF)
    static let ink = Color(hex: 0x1A1A1A)
    static let muted = Color(hex: 0x6F6E6A)
    static let selection = Color(hex: 0xEDEAE3)
    static let lavender = Color(hex: 0xF0D7FF)
    static let plum = Color(hex: 0x9A5BC4)
}

extension Font {
    static func serif(_ size: CGFloat) -> Font { .custom("EB Garamond", size: size) }
    static func sans(_ size: CGFloat, _ weight: Weight = .regular) -> Font { .custom("Figtree", size: size).weight(weight) }
}

extension View {
    func card(_ fill: Color = .well, radius: CGFloat = 12) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.line))
    }
}

// MARK: Shell

enum Page: String, CaseIterable {
    case home = "Home", sounds = "Sounds", settings = "Settings"

    var icon: String {
        switch self {
        case .home: "square.grid.2x2"
        case .sounds: "speaker.wave.2"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var page: Page = .home

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page)
            ScrollView {
                Group {
                    switch page {
                    case .home: HomePage(page: $page)
                    case .sounds: SoundsPage()
                    case .settings: SettingsPage()
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 44)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
            .background(Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line))
            .padding(.top, 44)
            .padding([.trailing, .bottom], 10)
        }
        .overlay(alignment: .topTrailing) { StatusChip().padding(.top, 9).padding(.trailing, 14) }
        .background(Color.chrome)
        .ignoresSafeArea()
        .frame(minWidth: 900, minHeight: 620)
        .font(.sans(14))
        .foregroundStyle(Color.ink)
        .preferredColorScheme(.light)
    }
}

struct Sidebar: View {
    @Binding var page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                Keycap(size: 24)
                Text("Thock").font(.serif(28))
            }
            .padding(.leading, 10).padding(.top, 50).padding(.bottom, 22)
            NavItem(page: .home, current: $page)
            NavItem(page: .sounds, current: $page)
            Spacer()
            NavItem(page: .settings, current: $page)
            Text("Thock v1.0").font(.sans(12)).foregroundStyle(Color.muted)
                .padding(.leading, 12).padding(.top, 12).padding(.bottom, 16)
        }
        .padding(.horizontal, 10)
        .frame(width: 204)
    }
}

struct NavItem: View {
    let page: Page
    @Binding var current: Page
    @State private var hover = false

    var body: some View {
        Button { current = page } label: {
            HStack(spacing: 11) {
                Image(systemName: page.icon).font(.system(size: 14)).frame(width: 18)
                Text(page.rawValue).font(.sans(15, .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(current == page ? Color.selection : hover ? Color.selection.opacity(0.55) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct Keycap: View {
    var size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color.ink)
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(Color(hex: 0x3A3A3A))
                    .frame(width: size * 0.74, height: size * 0.68)
                    .overlay(Text("T").font(.serif(size * 0.52)).foregroundStyle(.white))
                    .padding(.top, size * 0.09)
            }
    }
}

struct StatusChip: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let (label, dot): (String, Color) =
            !model.listening ? ("Needs permission", Color(hex: 0xE0663C))
            : model.enabled ? ("Listening", Color(hex: 0x2F9E6A))
            : ("Paused", Color(hex: 0xB8B5AD))
        Button {
            if model.listening { model.enabled.toggle() } else { model.requestAccess() }
        } label: {
            HStack(spacing: 7) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(label).font(.sans(12.5, .medium))
            }
            .padding(.horizontal, 11).padding(.vertical, 5)
            .card(.paper, radius: 20)
        }
        .buttonStyle(.plain)
        .help(model.listening ? "Click to pause or resume" : "Allow Input Monitoring")
    }
}

// MARK: Home

struct HomePage: View {
    @EnvironmentObject var model: AppModel
    @Binding var page: Page
    @State private var scratch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            PageHeader(title: greeting, subtitle: "Every key you press plays a little sound.")
            Hero()
            HStack(spacing: 14) {
                StatCard(value: model.today, label: "Keystrokes today")
                StatCard(value: model.total, label: "All time")
                NowPlaying(page: $page)
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Quick switch")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(model.allSounds) { SoundChip(sound: $0) }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Try it")
                TextField("Type anything here to hear it…", text: $scratch, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.sans(15))
                    .lineLimit(3...6)
                    .padding(14)
                    .card()
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }
}

struct Hero: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.serif(33)).foregroundStyle(.white)
                Text(detail).font(.sans(14.5)).foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if model.listening {
                Toggle("Sounds on", isOn: $model.enabled).toggleStyle(PillToggle(on: .lavender, knob: .ink))
            } else {
                Button("Allow access") { model.requestAccess() }.buttonStyle(PrimaryButton())
            }
        }
        .padding(.horizontal, 30).padding(.vertical, 26)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F3D36), Color(hex: 0x1E4A42), Color(hex: 0x3E3A2D)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.lavender.opacity(0.45)).frame(width: 260).blur(radius: 70).offset(x: 300, y: -70)
                Circle().fill(Color(hex: 0xF2AA5A).opacity(0.32)).frame(width: 220).blur(radius: 70).offset(x: -280, y: 80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var title: String {
        !model.listening ? "Let Thock hear your keyboard" : model.enabled ? "Thock is listening" : "Thock is paused"
    }

    private var detail: String {
        !model.listening ? "macOS asks you to allow Input Monitoring. Thock only notices that a key went down, never what you typed."
            : model.enabled ? "Playing \(model.selected.name) on every keystroke, in every app."
            : "Flip the switch to bring the sound back."
    }
}

struct StatCard: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value, format: .number)
                .font(.sans(34, .medium))
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy(duration: 0.2), value: value)
            Text(label.uppercased()).font(.sans(11.5, .semibold)).tracking(1.1).foregroundStyle(Color.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }
}

struct NowPlaying: View {
    @EnvironmentObject var model: AppModel
    @Binding var page: Page

    var body: some View {
        HStack(spacing: 14) {
            Emoji(sound: model.selected, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selected.name).font(.serif(27)).lineLimit(1)
                Button("Change sound →") { page = .sounds }
                    .buttonStyle(.plain).font(.sans(13, .medium)).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .card()
    }
}

struct SoundChip: View {
    @EnvironmentObject var model: AppModel
    let sound: Sound

    var body: some View {
        let on = model.selectedID == sound.id
        Button { model.select(sound) } label: {
            HStack(spacing: 7) {
                Text(sound.emoji)
                Text(sound.name).font(.sans(13.5, .medium)).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(Capsule().fill(on ? Color.ink : Color.well))
            .overlay(Capsule().strokeBorder(on ? Color.ink : Color.line))
            .foregroundStyle(on ? Color.white : Color.ink)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Sounds

struct SoundsPage: View {
    @EnvironmentObject var model: AppModel
    @State private var importing = false
    @State private var dropping = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            PageHeader(title: "Sounds", subtitle: "Pick what plays when you press a key. Hit ▶ to preview.")
            section("Classics") { ForEach(Presets.classics) { SoundCard(sound: $0) } }
            section("Just for fun") { ForEach(Presets.silly) { SoundCard(sound: $0) } }
            section("Your sounds") {
                ForEach(model.custom) { SoundCard(sound: $0) }
                AddSoundCard(dropping: dropping).onTapGesture { importing = true }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            add((try? result.get()) ?? [])
        }
        .dropDestination(for: URL.self) { urls, _ in
            add(urls)
            return true
        } isTargeted: { dropping = $0 }
        .alert("Couldn't add that sound", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: {
            Text(error ?? "")
        }
    }

    private func section(_ title: String, @ViewBuilder cards: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 178), spacing: 14)], spacing: 14, content: cards)
        }
    }

    private func add(_ urls: [URL]) {
        for url in urls {
            do { try model.importSound(url) } catch { self.error = "\(url.lastPathComponent): \(error.localizedDescription)" }
        }
    }
}

struct SoundCard: View {
    @EnvironmentObject var model: AppModel
    let sound: Sound
    @State private var hover = false

    var body: some View {
        let on = model.selectedID == sound.id
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Emoji(sound: sound, size: 44)
                Spacer()
                if on {
                    Tag("In use")
                } else if sound.isCustom && hover {
                    IconButton(symbol: "trash", label: "Remove \(sound.name)") { model.remove(sound) }
                }
            }
            Spacer(minLength: 14)
            Text(sound.name).font(.serif(27)).lineLimit(1)
            HStack(alignment: .bottom) {
                Text(sound.blurb).font(.sans(13)).foregroundStyle(Color.muted).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                IconButton(symbol: "play.fill", label: "Preview \(sound.name)") { model.preview(sound) }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(height: 172)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(hover && !on ? Color.well : Color.paper))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(on ? Color.ink : Color.line, lineWidth: on ? 1.5 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { model.select(sound) }
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
        .contextMenu {
            if sound.isCustom { Button("Remove", role: .destructive) { model.remove(sound) } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(sound.name)\(on ? ", in use" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.select(sound) }
    }
}

struct AddSoundCard: View {
    let dropping: Bool
    @State private var hover = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44).background(Circle().fill(Color.lavender))
            Text("Add a sound").font(.serif(25))
            Text("Drop an audio file, or click to browse").font(.sans(12.5)).foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(dropping ? Color.lavender.opacity(0.35) : hover ? Color.well : Color.paper))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(dropping ? Color.plum : Color.ink.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: Settings

struct SettingsPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            PageHeader(title: "Settings", subtitle: nil)
            SettingsGroup("Sound") {
                SettingsRow("Volume", "How loud each keystroke plays") {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                        Slider(value: $model.volume, in: 0...1).frame(width: 180).tint(Color.ink)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .font(.system(size: 11)).foregroundStyle(Color.muted)
                }
            }
            SettingsGroup("Keys") {
                SettingsRow("Modifier keys", "Also play for ⌘ ⌥ ⌃ ⇧ and Fn") {
                    Toggle("Modifier keys", isOn: $model.modifiers).toggleStyle(PillToggle())
                }
                RowDivider()
                SettingsRow("Key repeat", "Keep playing while a key is held down") {
                    Toggle("Key repeat", isOn: $model.repeats).toggleStyle(PillToggle())
                }
            }
            SettingsGroup("App") {
                SettingsRow("Typing pill", "A little pill at the bottom of the screen that dances while you type") {
                    Toggle("Typing pill", isOn: $model.showPill).toggleStyle(PillToggle())
                }
                RowDivider()
                SettingsRow("Open at login", "Start Thock quietly in the menu bar") {
                    Toggle("Open at login", isOn: Binding(get: { model.openAtLogin }, set: model.setOpenAtLogin))
                        .toggleStyle(PillToggle())
                }
                RowDivider()
                SettingsRow("Input Monitoring", model.listening
                            ? "Allowed. Thock can hear key presses in every app."
                            : "Not allowed yet, so key presses stay silent.") {
                    if model.listening {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.sans(13.5, .semibold)).foregroundStyle(Color(hex: 0x2F9E6A))
                    } else {
                        Button("Open System Settings") { model.requestAccess() }.buttonStyle(PrimaryButton())
                    }
                }
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.well))
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    init(_ title: String, _ subtitle: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.sans(15, .semibold))
                Text(subtitle).font(.sans(13.5)).foregroundStyle(Color.muted)
            }
            Spacer()
            control
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(Color.line).frame(height: 1).padding(.horizontal, 22) }
}

// MARK: Bits

struct PageHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.serif(46))
            if let subtitle { Text(subtitle).font(.sans(15)).foregroundStyle(Color.muted) }
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.sans(15, .semibold)) }
}

struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.sans(11.5, .semibold)).foregroundStyle(Color.plum)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.lavender.opacity(0.75)))
    }
}

struct Emoji: View {
    let sound: Sound
    var size: CGFloat = 44

    var body: some View {
        Text(sound.emoji).font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: sound.tint)))
            .accessibilityHidden(true)
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(hover ? Color.ink : Color.well))
                .overlay(Circle().strokeBorder(Color.line))
                .foregroundStyle(hover ? Color.white : Color.ink)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(label)
    }
}

/// Wispr-style black pill switch.
struct PillToggle: ToggleStyle {
    var on: Color = .ink
    var knob: Color = .white

    func makeBody(configuration c: Configuration) -> some View {
        Capsule()
            .fill(c.isOn ? on : Color(hex: 0xD9D6CE))
            .frame(width: 42, height: 25)
            .overlay(alignment: c.isOn ? .trailing : .leading) {
                Circle().fill(c.isOn ? knob : .white).padding(3).shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { c.isOn.toggle() } }
            .accessibilityRepresentation { Toggle(isOn: c.$isOn) { c.label } }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(.sans(14, .semibold)).foregroundStyle(Color.ink)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.lavender))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ink, lineWidth: 1.5))
            .scaleEffect(c.isPressed ? 0.97 : 1)
    }
}

// MARK: Floating pill (Wispr's "Flow bar", but it dances to your typing)

struct PillView: View {
    @EnvironmentObject var model: AppModel
    @State private var levels = Array(repeating: CGFloat(0.15), count: 9)
    @State private var awake = false
    @State private var sleep: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 10) {
            Text(model.selected.emoji).font(.system(size: 13))
            HStack(spacing: 3) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule().fill(.white).frame(width: 3, height: 3 + 15 * levels[i])
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(Color.ink))
        .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .scaleEffect(awake ? 1 : 0.5, anchor: .bottom)
        .opacity(awake && model.pillVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
        .onChange(of: model.pulse) { bump() }
    }

    private func bump() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
            awake = true
            levels = levels.indices.map { i in
                let center = 1 - abs(CGFloat(i) - 4) / 5   // taller in the middle, like a voice
                return max(0.15, center * .random(in: 0.5...1))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.4)) { levels = levels.map { max(0.12, $0 * 0.3) } }
        }
        sleep?.cancel()
        let work = DispatchWorkItem { withAnimation(.easeInOut(duration: 0.3)) { awake = false } }
        sleep = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

// MARK: Menu bar

struct MenuContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.listening {
            Toggle("Sounds On", isOn: $model.enabled)
        } else {
            Button("Allow Keyboard Access…") { model.requestAccess() }
        }
        Picker("Sound", selection: $model.selectedID) {
            ForEach(model.allSounds) { Text("\($0.emoji)  \($0.name)").tag($0.id) }
        }
        Divider()
        Button("Open Thock…") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Quit Thock") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
