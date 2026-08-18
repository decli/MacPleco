import SwiftUI
import AppKit

public struct MacPlecoApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage("com.macpleco.menubar") private var menuBarEnabled = true

    public init() {}

    public var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(model)
        }
        // The title bar is made transparent by AppDelegate rather than removed
        // by `.hiddenTitleBar`: a real (invisible) title bar keeps the system's
        // drag region, double-click zoom and full-screen behaviour, all of
        // which the hidden style silently discards.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarPanel()
                .environment(model)
        } label: {
            Image(systemName: "fish.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The menu bar panel keeps living when the window closes. The key is
        // unset until the user first touches the toggle, and unset means on.
        let stored = UserDefaults.standard.object(forKey: "com.macpleco.menubar") as? Bool
        return !(stored ?? true)
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { note in
            // The observer runs on the main queue but is not statically
            // isolated; hop explicitly before touching AppKit.
            let window = note.object as? NSWindow
            Task { @MainActor in
                if let window { Self.adoptChrome(window) }
            }
        }
        for window in NSApplication.shared.windows {
            Self.adoptChrome(window)
        }
    }

    /// Content extends under a transparent title bar. The bar itself stays, so
    /// dragging, double-click zoom and the green button all behave normally.
    static func adoptChrome(_ window: NSWindow) {
        guard window.styleMask.contains(.titled), !(window is NSPanel) else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
    }

    /// Brings the existing main window forward, or asks SwiftUI for a new one.
    @MainActor
    static func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: {
            $0.styleMask.contains(.titled) && !($0 is NSPanel) && $0.canBecomeMain
        }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
