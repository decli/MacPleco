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
        // Standard window chrome, on purpose. With NavigationSplitView the
        // title bar unifies with the glass toolbar, and dragging, double-click
        // zoom and full screen are the system's own behaviour.
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
