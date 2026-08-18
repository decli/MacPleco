import SwiftUI
import AppKit

enum AppPreference {
    static let menuBarEnabled = "com.macpleco.menubar"
}

public struct MacPlecoApp: App {
    @State private var model = AppModel()
    // Keep scene insertion state in SwiftUI, not in @AppStorage. Binding
    // MenuBarExtra(isInserted:) directly to @AppStorage triggers a scene/menu
    // invalidation loop on macOS 26: the main thread continuously rebuilds the
    // app menu, CPU pins, memory climbs, and the first window beach-balls.
    @State private var menuBarEnabled: Bool
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {
        let stored = UserDefaults.standard.object(forKey: AppPreference.menuBarEnabled) as? Bool
        _menuBarEnabled = State(initialValue: stored ?? true)
    }

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
            CommandMenu(t("前往", "Navigate")) {
                ForEach(Array(Destination.allCases.enumerated()), id: \.element) { index, destination in
                    Button(destination.title) {
                        model.destination = destination
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView(menuBarEnabled: persistedMenuBarBinding)
                .environment(model)
        }

        MenuBarExtra(isInserted: persistedMenuBarBinding) {
            MenuBarPanel()
                .environment(model)
        } label: {
            Image(systemName: "fish.fill")
        }
        .menuBarExtraStyle(.window)
    }

    /// Persistence happens at the edge. SwiftUI owns the scene state while
    /// UserDefaults only stores the next-launch value, avoiding the feedback
    /// loop caused by using @AppStorage as the scene binding itself.
    private var persistedMenuBarBinding: Binding<Bool> {
        Binding(
            get: { menuBarEnabled },
            set: { enabled in
                menuBarEnabled = enabled
                UserDefaults.standard.set(enabled, forKey: AppPreference.menuBarEnabled)
            }
        )
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The menu bar panel keeps living when the window closes. The key is
        // unset until the user first touches the toggle, and unset means on.
        let stored = UserDefaults.standard.object(forKey: AppPreference.menuBarEnabled) as? Bool
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
