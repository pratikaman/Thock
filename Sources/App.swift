import SwiftUI
import Combine

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--selftest") { SelfTest.run() }
        ThockApp.main()
    }
}

struct ThockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("Thock", id: "main") {
            RootView().environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 780)

        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            Image(systemName: model.enabled ? "keyboard.fill" : "keyboard")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pill: PillPanel?

    func applicationDidFinishLaunching(_ note: Notification) {
        AppModel.shared.startListening()
        pill = PillPanel(model: AppModel.shared)
        DispatchQueue.main.async {
            NSApp.windows.filter { $0.identifier?.rawValue == "main" }.forEach { $0.isMovableByWindowBackground = true }
        }
    }
}

/// Click-through panel at the bottom of the screen that hosts the typing meter.
final class PillPanel: NSPanel {
    private var sink: AnyCancellable?
    private var lastPulse = Date.distantPast

    init(model: AppModel) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 240, height: 64),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: PillView().environmentObject(model))
        sink = model.$pulse.dropFirst().sink { [weak self] _ in self?.wake() }
        wake()
    }

    /// After a pause in typing, re-centre on whichever display the user is typing on.
    private func wake() {
        if Date().timeIntervalSince(lastPulse) > 1.5, let screen = NSScreen.main {
            let v = screen.visibleFrame
            setFrameOrigin(NSPoint(x: v.midX - frame.width / 2, y: v.minY + 6))
            orderFrontRegardless()
        }
        lastPulse = Date()
    }
}
