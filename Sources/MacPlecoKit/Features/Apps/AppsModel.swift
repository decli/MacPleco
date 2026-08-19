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

    /// How to order the login items.
    ///
    /// "Runs at login" first is the one that answers the question the page is
    /// really for — *what actually starts when I turn this Mac on* — which the
    /// old fixed ordering buried among entries that only sit there registered.
    public enum StartupSortKey: String, CaseIterable, Identifiable {
        case runsAtLoad
        case name
        case scope

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .runsAtLoad: return t("开机即启动", "Runs at login")
            case .name: return t("名称", "Name")
            case .scope: return t("范围", "Scope")
            }
        }
    }

    public var tab: Tab = .installed
    public var sort: SortKey = .lastUsed
    public var query = ""
    public var showSystemApps = false

    public var startupSort: StartupSortKey = .runsAtLoad
    public var startupQuery = ""

    public private(set) var isSizing = false
    public private(set) var loginItems: [LoginItem] = []
    public private(set) var isLoadingStartup = false

    /// Non-nil while a confirmation sheet is up.
    public var plan: UninstallPlan?
    public var batchPlan: BatchUninstallPlan?
    public private(set) var isPlanning = false
    public private(set) var isUninstalling = false
    public private(set) var planningProgress: (done: Int, total: Int)?
    public private(set) var uninstallProgress: (done: Int, total: Int)?
    public private(set) var lastUninstalled: (name: String, bytes: Int64)?

    /// Bundle identifiers ticked in the list, for a batch uninstall.
    public private(set) var selection: Set<String> = []

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

    /// Login items after search and sorting.
    public var visibleLoginItems: [LoginItem] {
        var items = loginItems

        let trimmed = startupQuery.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(trimmed)
                    || $0.label.localizedCaseInsensitiveContains(trimmed)
                    || $0.program.localizedCaseInsensitiveContains(trimmed)
            }
        }

        switch startupSort {
        case .name:
            items.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .runsAtLoad:
            items.sort { lhs, rhs in
                if lhs.runsAtLoad != rhs.runsAtLoad { return lhs.runsAtLoad }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        case .scope:
            items.sort { lhs, rhs in
                // Yours first: those are the ones removable from here.
                if lhs.isUserScope != rhs.isUserScope { return lhs.isUserScope }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        }
        return items
    }

    public var runsAtLoadCount: Int {
        loginItems.filter(\.runsAtLoad).count
    }

    // MARK: - Selection

    /// Only apps that can actually be uninstalled are selectable; ticking a
    /// system app would promise something the app will not do.
    public func isSelectable(_ app: InstalledApp) -> Bool {
        !app.isSystem
    }

    public func isSelected(_ app: InstalledApp) -> Bool {
        selection.contains(app.id)
    }

    public func toggleSelection(_ app: InstalledApp) {
        guard isSelectable(app) else { return }
        if selection.contains(app.id) {
            selection.remove(app.id)
        } else {
            selection.insert(app.id)
        }
    }

    /// Select-all applies to what is on screen, not to everything installed —
    /// a select-all that reached past the current search would be a trap.
    public func toggleSelectAll(in apps: [InstalledApp]) {
        let selectable = apps.filter(isSelectable).map(\.id)
        guard !selectable.isEmpty else { return }
        if selectable.allSatisfy(selection.contains) {
            selection.subtract(selectable)
        } else {
            selection.formUnion(selectable)
        }
    }

    public func allSelected(in apps: [InstalledApp]) -> Bool {
        let selectable = apps.filter(isSelectable).map(\.id)
        return !selectable.isEmpty && selectable.allSatisfy(selection.contains)
    }

    public func clearSelection() {
        selection.removeAll()
    }

    public var selectedCount: Int { selection.count }

    // MARK: - Uninstall

    public func preparePlan(for app: InstalledApp) async {
        guard !isPlanning else { return }
        isPlanning = true
        plan = await Uninstaller.plan(for: app)
        isPlanning = false
    }

    public func prepareBatchPlan(registry: AppRegistry) async {
        guard !isPlanning, !selection.isEmpty else { return }
        let apps = registry.apps.filter { selection.contains($0.id) && !$0.isSystem }
        guard !apps.isEmpty else { return }

        isPlanning = true
        planningProgress = (0, apps.count)
        batchPlan = await Uninstaller.batchPlan(for: apps) { [weak self] done in
            self?.planningProgress = (done, apps.count)
        }
        planningProgress = nil
        isPlanning = false
    }

    public func toggleLeftover(_ id: String) {
        guard var current = plan,
              let index = current.leftovers.firstIndex(where: { $0.id == id })
        else { return }
        current.leftovers[index].isSelected.toggle()
        plan = current
    }

    public func toggleBatchApp(_ appID: String) {
        guard var current = batchPlan else { return }
        if current.excluded.contains(appID) {
            current.excluded.remove(appID)
        } else {
            current.excluded.insert(appID)
        }
        batchPlan = current
    }

    public func toggleBatchLeftover(appID: String, leftoverID: String) {
        guard var current = batchPlan,
              let planIndex = current.plans.firstIndex(where: { $0.id == appID }),
              let index = current.plans[planIndex].leftovers.firstIndex(where: { $0.id == leftoverID })
        else { return }
        current.plans[planIndex].leftovers[index].isSelected.toggle()
        batchPlan = current
    }

    public func confirmUninstall(registry: AppRegistry, storage: StorageModel) async {
        guard let plan, !isUninstalling else { return }
        isUninstalling = true

        let outcome = await Uninstaller.execute(plan)
        if !outcome.removed.isEmpty {
            lastUninstalled = (plan.app.name, outcome.bytes)
            selection.remove(plan.app.id)
            await registry.load(force: true)
            storage.refresh()
        }

        self.plan = nil
        isUninstalling = false
    }

    /// Runs the batch one app at a time so a failure part-way through leaves a
    /// coherent state — and so the sheet can say which app it is on.
    public func confirmBatchUninstall(registry: AppRegistry, storage: StorageModel) async {
        guard let batchPlan, !isUninstalling else { return }
        let plans = batchPlan.selectedPlans
        guard !plans.isEmpty else { return }

        isUninstalling = true
        uninstallProgress = (0, plans.count)

        var freed: Int64 = 0
        var removedCount = 0
        for (index, plan) in plans.enumerated() {
            let outcome = await Uninstaller.execute(plan)
            if !outcome.removed.isEmpty {
                freed += outcome.bytes
                removedCount += 1
                selection.remove(plan.app.id)
            }
            uninstallProgress = (index + 1, plans.count)
        }

        if removedCount > 0 {
            lastUninstalled = (
                t("\(removedCount) 个应用", "\(removedCount) apps"),
                freed
            )
            await registry.load(force: true)
            storage.refresh()
        }

        uninstallProgress = nil
        self.batchPlan = nil
        isUninstalling = false
    }

    public func cancelUninstall() {
        plan = nil
        batchPlan = nil
    }

    // MARK: - Startup

    public func removeLoginItem(_ item: LoginItem) async {
        guard await LoginItems.remove(item) else { return }
        loginItems.removeAll { $0.id == item.id }
    }
}
