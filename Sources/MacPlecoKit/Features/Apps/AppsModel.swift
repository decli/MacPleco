import Foundation
import Observation

@Observable
@MainActor
public final class AppsModel {

    public enum Tab: String, CaseIterable, Identifiable {
        case installed
        case startup

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .installed: return t("已安装", "Installed")
            case .startup: return t("开机启动", "Starts at login")
            }
        }
    }

    public enum SortKey: String, CaseIterable, Identifiable {
        case lastUsed
        case size
        case name

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .lastUsed: return t("最久未用", "Least used")
            case .size: return t("占用最大", "Largest")
            case .name: return t("名称", "Name")
            }
        }
    }

    public var tab: Tab = .installed
    public var sort: SortKey = .lastUsed
    public var query = ""
    public var showSystemApps = false

    public private(set) var isSizing = false
    public private(set) var loginItems: [LoginItem] = []
    public private(set) var isLoadingStartup = false

    /// Non-nil while the confirmation sheet is up.
    public var plan: UninstallPlan?
    public private(set) var isPlanning = false
    public private(set) var isUninstalling = false
    public private(set) var lastUninstalled: (name: String, bytes: Int64)?

    private var sizeToken: ScanToken?

    public init() {}

    // MARK: - Loading

    public func load(registry: AppRegistry) async {
        await registry.load()
        guard !isSizing else { return }
        isSizing = true
        let token = ScanToken()
        sizeToken = token
        await registry.loadSizes(token: token)
        isSizing = false
    }

    public func loadStartup() async {
        guard !isLoadingStartup else { return }
        isLoadingStartup = true
        loginItems = await LoginItems.load()
        isLoadingStartup = false
    }

    // MARK: - Filtering

    public func visibleApps(registry: AppRegistry) -> [InstalledApp] {
        var apps = registry.apps
        if !showSystemApps {
            apps = apps.filter { !$0.isSystem }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.id.localizedCaseInsensitiveContains(trimmed)
            }
        }

        switch sort {
        case .name:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            apps.sort { $0.size > $1.size }
        case .lastUsed:
            // Never-opened apps are the most interesting answer to "what can I
            // remove", so they sort to the top rather than the bottom.
            apps.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
        return apps
    }

    // MARK: - Uninstall

    public func preparePlan(for app: InstalledApp) async {
        guard !isPlanning else { return }
        isPlanning = true
        plan = await Uninstaller.plan(for: app)
        isPlanning = false
    }

    public func toggleLeftover(_ id: String) {
        guard var current = plan,
              let index = current.leftovers.firstIndex(where: { $0.id == id })
        else { return }
        current.leftovers[index].isSelected.toggle()
        plan = current
    }

    public func confirmUninstall(registry: AppRegistry, storage: StorageModel) async {
        guard let plan, !isUninstalling else { return }
        isUninstalling = true

        let outcome = await Uninstaller.execute(plan)
        if !outcome.removed.isEmpty {
            lastUninstalled = (plan.app.name, outcome.bytes)
            await registry.load(force: true)
            storage.refresh()
        }

        self.plan = nil
        isUninstalling = false
    }

    public func cancelUninstall() {
        plan = nil
    }

    // MARK: - Startup

    public func removeLoginItem(_ item: LoginItem) async {
        guard await LoginItems.remove(item) else { return }
        loginItems.removeAll { $0.id == item.id }
    }
}
