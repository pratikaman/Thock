import SwiftUI
import UniformTypeIdentifiers

// MARK: Workbench theme

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static let canvas = Color(hex: 0xF3F5F8)
    static let surface = Color.white
    static let inset = Color(hex: 0xEBEFF5)
    static let line = Color(hex: 0xDFE4ED)
    static let ink = Color(hex: 0x1C2940)
    static let muted = Color(hex: 0x657187)
    static let accent = Color(hex: 0x325EF5)
    static let accentWash = Color(hex: 0xEAF0FF)
    static let positive = Color(hex: 0x267457)
}

extension Font {
    static func display(_ size: CGFloat) -> Font { .custom("AvenirNext-Bold", size: size) }
    static func bodyText(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "AvenirNext-DemiBold" : "AvenirNext-Medium", size: size)
    }
    static func technical(_ size: CGFloat) -> Font { .custom("Menlo-Regular", size: size) }
}

extension View {
    func panel(fill: Color = .surface, radius: CGFloat = 18) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.line))
    }
}

extension Sound {
    var symbol: String {
        switch id {
        case "keyboard": "keyboard"
        case "typewriter": "textformat.abc"
        case "pop": "bubbles.and.sparkles"
        case "gun": "burst"
        case "meow": "cat"
        case "bark": "dog"
        case "quack": "bird"
        default: "waveform"
        }
    }
}

// MARK: Window shell

enum Page: String, CaseIterable {
    case studio = "Playground", sounds = "Sounds", settings = "Settings"

    var icon: String {
        switch self {
        case .studio: "keyboard"
        case .sounds: "square.stack.3d.up"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @State private var page: Page

    init(page: Page = .studio) { _page = State(initialValue: page) }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(page: $page)
            Rectangle().fill(Color.line).frame(height: 1)
            ScrollView {
                Group {
                    switch page {
                    case .studio: StudioPage(page: $page)
                    case .sounds: SoundsPage()
                    case .settings: SettingsPage()
                    }
                }
                .padding(.horizontal, 30).padding(.vertical, 24)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            BottomBar()
        }
        .background(Color.canvas)
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 700)
        .font(.bodyText(14))
        .foregroundStyle(Color.ink)
        .tint(Color.accent)
        .preferredColorScheme(.light)
    }
}

struct TopBar: View {
    @Binding var page: Page

    var body: some View {
        HStack(spacing: 30) {
            HStack(spacing: 10) {
                BrandMark()
                Text("thock.").font(.display(27)).tracking(-1.2)
            }
            .frame(width: 160, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(Page.allCases, id: \.self) { item in
                    Button { page = item } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.icon).font(.system(size: 13, weight: .semibold))
                            Text(item.rawValue).font(.bodyText(13, bold: true))
                        }
                        .padding(.horizontal, 15).frame(height: 36)
                        .foregroundStyle(page == item ? Color.accent : Color.muted)
                        .background(RoundedRectangle(cornerRadius: 9).fill(page == item ? Color.accentWash : .clear))
                    }
                    .buttonStyle(QuietButton())
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }
            Spacer(minLength: 8)
            StatusControl()
        }
        .padding(.horizontal, 30)
        .padding(.top, 32).padding(.bottom, 16)
        .background(Color.surface)
    }
}

struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(Color.accent)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach([10.0, 18.0, 13.0], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 4, height: height)
                }
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

struct StatusControl: View {
    @EnvironmentObject var model: AppModel

    private var title: String {
        if !model.listening { return "Enable keyboard" }
        if !model.enabled { return "Sound paused" }
        return model.secureInputApp == nil ? "Sound is on" : "Secure Input"
    }

    var body: some View {
        Button {
            if model.listening { model.enabled.toggle() } else { model.requestAccess() }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(model.listening && model.enabled && model.secureInputApp == nil ? Color.positive : Color.muted)
                    .frame(width: 6, height: 6)
                Text(title).font(.bodyText(12, bold: true))
                Image(systemName: model.listening ? (model.enabled ? "pause.fill" : "play.fill") : "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 13).frame(height: 34)
            .panel(radius: 8)
        }
        .buttonStyle(QuietButton())
        .help(model.listening ? "Pause or resume keystroke sounds" : "Allow Input Monitoring in System Settings")
    }
}

struct BottomBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield").font(.system(size: 11))
            Text("Just sound. Your typing stays yours.").font(.bodyText(11))
            Spacer()
            Text(model.today.formatted()).foregroundStyle(Color.ink)
            Text("TODAY")
            Rectangle().fill(Color.line).frame(width: 1, height: 12).padding(.horizontal, 9)
            Text(model.total.formatted()).foregroundStyle(Color.ink)
            Text("ALL TIME")
        }
        .font(.technical(10)).foregroundStyle(Color.muted)
        .padding(.horizontal, 30).frame(height: 38)
        .background(Color.surface)
        .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
    }
}

// MARK: Playground

struct StudioPage: View {
    @EnvironmentObject var model: AppModel
    @Binding var page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Good keys. Great sound.", subtitle: "Give your everyday typing a little personality.")
                Spacer()
                Text("MAKE SOME KEY NOISE").font(.technical(9)).tracking(1.1).foregroundStyle(Color.muted)
                    .padding(.bottom, 5)
            }
            HStack(alignment: .top, spacing: 18) {
                KeyboardPlayground().frame(maxWidth: .infinity)
                SoundInspector().frame(width: 252)
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Eyebrow("PICK YOUR SOUND")
                    Spacer()
                    Button { page = .sounds } label: {
                        HStack(spacing: 6) {
                            Text("Explore library")
                            Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                        }
                        .font(.bodyText(12, bold: true)).foregroundStyle(Color.accent)
                    }
                    .buttonStyle(QuietButton())
                }
                HStack(spacing: 9) {
                    ForEach(Presets.classics + Presets.silly) { SoundTile(sound: $0) }
                }
            }
        }
    }
}

struct KeyboardPlayground: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scratch = ""
    @State private var pressed = false
    @State private var release: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow("THE PLAYGROUND")
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(model.listening && model.enabled && model.secureInputApp == nil ? Color.positive : Color.muted)
                        .frame(width: 5, height: 5)
                    Text(status).font(.technical(9))
                }
                .foregroundStyle(Color.muted)
            }
            .padding(22)
            ZStack {
                DotGrid().foregroundStyle(Color(hex: 0xCDD5E1)).padding(.horizontal, 10)
                VStack(spacing: 16) {
                    MechanicalKeyboard(pressed: pressed) {
                        model.preview(model.selected)
                        bump()
                    }
                    .padding(.horizontal, 28)
                    HStack(spacing: 6) {
                        Image(systemName: "cursorarrow").font(.system(size: 10))
                        Text("Click the space bar to preview").font(.bodyText(11))
                    }
                    .foregroundStyle(Color.muted)
                }
            }
            .frame(height: 217)
            VStack(alignment: .leading, spacing: 10) {
                TextField("Type here. Find your happy sound.", text: $scratch)
                    .textFieldStyle(.plain).font(.bodyText(13))
                    .padding(.horizontal, 14).frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.surface))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.line))
                    .accessibilityLabel("Typing playground")
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: model.listening ? "info.circle" : "keyboard.badge.ellipsis")
                        .font(.system(size: 10)).padding(.top, 2)
                    Text(hint).font(.bodyText(10)).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
        }
        .frame(height: 386, alignment: .top)
        .panel(fill: Color(hex: 0xF8FAFD))
        .onChange(of: model.pulse) { bump() }
        .onDisappear { release?.cancel(); pressed = false }
    }

    private var status: String {
        if !model.listening { return "PREVIEW ONLY" }
        if !model.enabled { return "PAUSED" }
        return model.secureInputApp == nil ? "READY WHEN YOU ARE" : "SECURE INPUT"
    }

    private var hint: String {
        if !model.listening { return "Enable keyboard access above to hear sounds as you type." }
        if !model.enabled { return "Sounds are paused. You can still preview with the space bar above." }
        if let app = model.secureInputApp { return "\(app) has Secure Input on. Sounds return when it turns off." }
        return "Works in every app. Thock never records what you type."
    }

    private func bump() {
        release?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.08)) { pressed = true }
        let work = DispatchWorkItem {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pressed = false }
        }
        release = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}

struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(10), to: size.width, by: 18) {
                for y in stride(from: CGFloat(8), to: size.height, by: 18) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .foreground)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MechanicalKeyboard: View {
    let pressed: Bool
    let preview: () -> Void
    private let rows = [
        ["esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "⌫"],
        ["tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "["],
        ["⇪", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "↵"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "⇧"],
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        KeyboardKey(label: rows[row][column], accent: row == 0 && column == 0)
                    }
                }
                .accessibilityHidden(true)
            }
            HStack(spacing: 4) {
                KeyboardKey(label: "fn").frame(maxWidth: 36)
                KeyboardKey(label: "⌃").frame(maxWidth: 36)
                KeyboardKey(label: "⌥").frame(maxWidth: 36)
                KeyboardKey(label: "⌘").frame(maxWidth: 40)
                Button(action: preview) {
                    HStack(spacing: 7) {
                        Image(systemName: "waveform").font(.system(size: 10, weight: .bold))
                        Text("thock").font(.bodyText(11, bold: true)).tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 31)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accent))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.2)))
                    .compositingGroup()
                    .shadow(color: Color(hex: 0x1C3DB6), radius: 0, y: pressed ? 1 : 3)
                    .offset(y: pressed ? 2 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview current sound")
                .help("Preview current sound")
                KeyboardKey(label: "⌘").frame(maxWidth: 40)
                KeyboardKey(label: "←").frame(maxWidth: 36)
                KeyboardKey(label: "→").frame(maxWidth: 36)
            }
        }
        .padding(12).padding(.bottom, 3)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0xDCE2EC)))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color(hex: 0xCDD5E1)))
        .compositingGroup()
        .shadow(color: Color(hex: 0xB7C2D3), radius: 0, y: 6)
        .shadow(color: Color.ink.opacity(0.10), radius: 12, y: 13)
        .rotationEffect(.degrees(-3))
    }
}

struct KeyboardKey: View {
    let label: String
    var accent = false

    var body: some View {
        Text(label).font(.technical(label.count > 1 ? 8 : 10))
            .foregroundStyle(accent ? Color.accent : Color(hex: 0x788397))
            .frame(maxWidth: .infinity).frame(height: 25)
            .background(RoundedRectangle(cornerRadius: 4).fill(accent ? Color.accentWash : Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.8)))
            .compositingGroup()
            .shadow(color: Color(hex: 0xB9C3D2), radius: 0, y: 2)
            .accessibilityHidden(true)
    }
}

struct SoundInspector: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("ON YOUR KEYS")
                Spacer()
                Image(systemName: "arrow.down.left").font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            .padding(.bottom, 20)
            HStack {
                SoundGlyph(sound: model.selected, size: 48, selected: true)
                Spacer()
                DecorativeWave(seed: model.selected.id, color: .accent).frame(width: 78, height: 30)
            }
            .padding(.bottom, 14)
            Text(model.selected.name).font(.display(27)).lineLimit(1).minimumScaleFactor(0.6)
            Text(model.selected.blurb).font(.bodyText(12)).foregroundStyle(Color.muted)
                .lineLimit(2).frame(height: 38, alignment: .top).padding(.top, 3)
            Spacer(minLength: 12)
            HStack {
                Eyebrow("VOLUME")
                Spacer()
                Text("\(Int(model.volume * 100))%").font(.technical(11)).foregroundStyle(Color.muted)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.system(size: 10))
                Slider(value: $model.volume, in: 0...1).accessibilityLabel("Sound volume")
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 10))
            }
            .foregroundStyle(Color.muted).padding(.top, 6).padding(.bottom, 17)
            Button { model.preview(model.selected) } label: {
                Label("Preview sound", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButton())
        }
        .padding(22).frame(height: 386)
        .panel()
    }
}

struct SoundTile: View {
    @EnvironmentObject var model: AppModel
    let sound: Sound

    var body: some View {
        let selected = model.selectedID == sound.id
        Button { model.select(sound) } label: {
            VStack(spacing: 11) {
                Image(systemName: sound.symbol).font(.system(size: 21, weight: .regular)).frame(height: 23)
                Text(sound.name).font(.bodyText(11, bold: true)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.accent : Color.muted)
            .frame(maxWidth: .infinity).frame(height: 83)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.accentWash : Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accent.opacity(0.65) : Color.line))
            .overlay(alignment: .topTrailing) {
                if selected { Circle().fill(Color.accent).frame(width: 5, height: 5).padding(9) }
            }
        }
        .buttonStyle(QuietButton())
        .accessibilityLabel("\(sound.name)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Sound library

enum SoundCategory: String, CaseIterable {
    case all = "All sounds", classics = "Essentials", playful = "Playful", custom = "Imported"
}

struct SoundsPage: View {
    @EnvironmentObject var model: AppModel
    @State private var category: SoundCategory = .all
    @State private var importing = false
    @State private var dropping = false
    @State private var error: String?

    private var sounds: [Sound] {
        switch category {
        case .all: model.allSounds
        case .classics: Presets.classics
        case .playful: Presets.silly
        case .custom: model.custom
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center) {
                PageHeader(title: "A sound for every mood.", subtitle: "From satisfying clicks to the slightly ridiculous. Make it yours.")
                Spacer()
                Button { importing = true } label: { Label("Import audio", systemImage: "plus") }
                    .buttonStyle(PrimaryButton())
            }
            HStack(spacing: 6) {
                ForEach(SoundCategory.allCases, id: \.self) { item in
                    Button { category = item } label: {
                        Text(item.rawValue).font(.bodyText(12, bold: true))
                            .padding(.horizontal, 15).padding(.vertical, 9)
                            .foregroundStyle(category == item ? Color.surface : Color.muted)
                            .background(RoundedRectangle(cornerRadius: 8).fill(category == item ? Color.ink : .clear))
                    }
                    .buttonStyle(QuietButton())
                    .accessibilityAddTraits(category == item ? .isSelected : [])
                }
                Spacer()
                Text("\(sounds.count) SOUNDS").font(.technical(10)).foregroundStyle(Color.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(sounds) { SoundCard(sound: $0) }
            }
            Button { importing = true } label: {
                HStack(spacing: 16) {
                    Image(systemName: "waveform.badge.plus").font(.system(size: 23)).foregroundStyle(Color.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.custom.isEmpty ? "Got a sound of your own?" : "Make room for one more.")
                            .font(.bodyText(14, bold: true)).foregroundStyle(Color.ink)
                        Text("Drop an audio file here, or browse to add it to your collection.")
                            .font(.bodyText(12)).foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(Color.accent)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13).fill(dropping ? Color.accentWash : Color.surface.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(dropping ? Color.accent : Color(hex: 0xB6C2D6), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(QuietButton())
            .accessibilityLabel("Import your own sound")
            Text("Your sounds stay on this Mac. Short clips work best.")
                .font(.bodyText(11)).foregroundStyle(Color.muted)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): add(urls)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            add(urls)
            return true
        } isTargeted: { dropping = $0 }
        .alert("Couldn't add that sound", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func add(_ urls: [URL]) {
        for url in urls {
            do {
                try model.importSound(url)
                category = .custom
            } catch { self.error = "\(url.lastPathComponent): \(error.localizedDescription)" }
        }
    }
}

struct SoundCard: View {
    @EnvironmentObject var model: AppModel
    let sound: Sound

    var body: some View {
        let selected = model.selectedID == sound.id
        HStack(spacing: 0) {
            Button { model.select(sound) } label: {
                HStack(spacing: 14) {
                    SoundGlyph(sound: sound, size: 46, selected: selected)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(sound.name).font(.bodyText(15, bold: true)).lineLimit(1)
                            if selected {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color.accent)
                            }
                        }
                        Text(sound.blurb).font(.bodyText(11)).foregroundStyle(Color.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading).frame(height: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButton())
            .accessibilityLabel("Select \(sound.name)\(selected ? ", selected" : "")")
            .accessibilityAddTraits(selected ? .isSelected : [])
            HStack(spacing: 7) {
                if sound.isCustom {
                    IconButton(symbol: "trash", label: "Remove \(sound.name)") { model.remove(sound) }
                }
                IconButton(symbol: "play.fill", label: "Preview \(sound.name)") { model.preview(sound) }
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 17).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 13).fill(selected ? Color.accentWash.opacity(0.6) : Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Color.accent.opacity(0.6) : Color.line))
        .contextMenu {
            Button("Preview") { model.preview(sound) }
            if sound.isCustom { Button("Remove", role: .destructive) { model.remove(sound) } }
        }
    }
}

// MARK: Settings

struct SettingsPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            PageHeader(title: "A few fine adjustments.", subtitle: "Set it once. Get back to doing your thing.")
            SettingsGroup(title: "Sound & keys", subtitle: "Make every press feel right.", symbol: "slider.horizontal.3") {
                SettingsRow("Volume", "The loudness of each keystroke") {
                    HStack(spacing: 12) {
                        Slider(value: $model.volume, in: 0...1).frame(width: 140).accessibilityLabel("Sound volume")
                        Text("\(Int(model.volume * 100))%").font(.technical(11)).frame(width: 36, alignment: .trailing)
                    }
                }
                RowDivider()
                SettingsRow("Modifier keys", "Play sounds for ⌘, ⌥, ⌃, ⇧ and Fn") {
                    Toggle("Modifier keys", isOn: $model.modifiers).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                RowDivider()
                SettingsRow("Key repeat", "Keep playing while a key is held down") {
                    Toggle("Key repeat", isOn: $model.repeats).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
            SettingsGroup(title: "At home on your Mac", subtitle: "Little details. Your call.", symbol: "macwindow") {
                SettingsRow("Typing indicator", "A tiny sound meter at the bottom of your screen") {
                    Toggle("Typing indicator", isOn: $model.showPill).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                RowDivider()
                SettingsRow("Open at login", "Have Thock ready when you start your Mac") {
                    Toggle("Open at login", isOn: Binding(get: { model.openAtLogin }, set: model.setOpenAtLogin))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
            SettingsGroup(title: "Keyboard access", subtitle: "Private by design.", symbol: "lock.shield") {
                SettingsRow("Input Monitoring", model.listening
                            ? "Allowed. Key presses can trigger sounds in any app."
                            : "Allow access to play sounds outside the playground preview.") {
                    if model.listening {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.bodyText(12, bold: true)).foregroundStyle(Color.positive)
                    } else {
                        Button("Allow access") { model.requestAccess() }.buttonStyle(SecondaryButton())
                    }
                }
            }
            HStack(spacing: 7) {
                BrandMark().scaleEffect(0.6).frame(width: 20, height: 20)
                Text("Thock 1.0").font(.bodyText(11, bold: true))
                Text("/  A little joy in every keystroke.").font(.bodyText(11)).foregroundStyle(Color.muted)
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Color.accent).padding(.bottom, 5)
                Text(title).font(.bodyText(15, bold: true))
                Text(subtitle).font(.bodyText(12)).foregroundStyle(Color.muted)
            }
            .frame(width: 196, alignment: .leading).padding(.top, 15)
            VStack(spacing: 0) { content }.frame(maxWidth: .infinity).panel(radius: 13)
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
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.bodyText(13, bold: true))
                Text(subtitle).font(.bodyText(11)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            control
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(Color.line).frame(height: 1).padding(.horizontal, 20) }
}

// MARK: Shared controls

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.display(31)).tracking(-1)
            Text(subtitle).font(.bodyText(13)).foregroundStyle(Color.muted)
        }
    }
}

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.technical(9)).tracking(1.2).foregroundStyle(Color.muted)
    }
}

struct SoundGlyph: View {
    let sound: Sound
    let size: CGFloat
    var selected = false

    var body: some View {
        Image(systemName: sound.symbol).font(.system(size: size * 0.45, weight: .regular))
            .foregroundStyle(selected ? Color.accent : Color.ink)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.24).fill(selected ? Color.accentWash : Color.canvas))
            .accessibilityHidden(true)
    }
}

/// A decorative sound motif, not a measured waveform or recording indicator.
struct DecorativeWave: View {
    let seed: String
    let color: Color

    var body: some View {
        let offset = seed.utf8.reduce(0) { $0 + Int($1) }
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<15) { i in
                    let height = 0.18 + abs(sin(Double(i * 7 + offset) * 0.37)) * 0.82
                    Capsule().fill(color.opacity(i % 3 == 0 ? 0.45 : 0.8))
                        .frame(width: 2, height: geo.size.height * height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accent).frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentWash))
        }
        .buttonStyle(QuietButton()).accessibilityLabel(label).help(label)
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButtonContent(content: configuration.label, pressed: configuration.isPressed)
    }
}

private struct QuietButtonContent<Content: View>: View {
    let content: Content
    let pressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        content
            .opacity(pressed ? 0.65 : hovering ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyText(12, bold: true)).foregroundStyle(.white)
            .padding(.horizontal, 16).frame(height: 39)
            .background(RoundedRectangle(cornerRadius: 9).fill(configuration.isPressed ? Color.accent.opacity(0.8) : Color.accent))
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyText(12, bold: true)).foregroundStyle(Color.accent)
            .padding(.horizontal, 13).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentWash))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: Floating typing meter

struct PillView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var awake = false
    @State private var sleep: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.selected.symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.accent)
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<7) { i in
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.accent.opacity(i % 2 == 0 ? 1 : 0.5))
                        .frame(width: 3, height: awake && !reduceMotion ? CGFloat(5 + (i * 7 + model.pulse * 3) % 14) : 8)
                }
            }
            Rectangle().fill(Color.line).frame(width: 1, height: 13)
            Text(model.selected.name).font(.bodyText(10, bold: true)).lineLimit(1).frame(maxWidth: 70)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.line))
        .shadow(color: Color.ink.opacity(0.12), radius: 8, y: 3)
        .offset(y: awake || reduceMotion ? 0 : 6)
        .opacity(awake && model.pillVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
        .foregroundStyle(Color.ink).preferredColorScheme(.light)
        .accessibilityHidden(true)
        .onChange(of: model.pulse) { bump() }
        .onDisappear { sleep?.cancel() }
    }

    private func bump() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { awake = true }
        sleep?.cancel()
        let work = DispatchWorkItem {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { awake = false }
        }
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
