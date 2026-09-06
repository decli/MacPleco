import Foundation
import Observation
import AppKit

@Observable
@MainActor
public final class CleanModel {

    public enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case cleaning
        case finished(bytes: Int64, trashed: Int, erased: Int)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var categories: [CleanCategory] = []
    public private(set) var blockedApps: [BlockedApp] = []
    public private(set) var progress: ScanProgress?
    public private(set) var hasScanned = false
    public private(set) var lastFailures: Int = 0

    /// Apps that started running between the scan and the click, whose caches
    /// were therefore left alone. Reported rather than silently dropped.
    public private(set) var lastSkipped: [BlockedApp] = []

    /// Categories the user has opened. Nothing is expanded to begin with — the
    /// summary is the point, and the detail is there for those who want it.
    public var expanded: Set<CleanCategoryID> = []

    /// Off by default and re-armed after every run. Erasing outright removes
    /// the safety net the whole design rests on, so it is never sticky.
    public var permanentDelete = false

    private var token: ScanToken?

    public init() {}

    // MARK: - Derived

    public var totalSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    public var selectedSize: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }
    public var selectedCount: Int { categories.reduce(0) { $0 + $1.selectedCount } }
    public var itemCount: Int { categories.reduce(0) { $0 + $1.items.count } }
    public var blockedBytes: Int64 { blockedApps.reduce(0) { $0 + $1.bytes } }

    public var isScanning: Bool { phase == .scanning }
    public var isCleaning: Bool { phase == .cleaning }
    public var isBusy: Bool { isScanning || isCleaning }

    /// True when the selection includes anything that cannot be undone.
    public var selectionIncludesPermanent: Bool {
        permanentDelete || categories.contains {
            $0.id.requiresPermanentDeletion && $0.selectedCount > 0
        }
    }

    // MARK: - Scanning

    public func scanIfNeeded(registry: AppRegistry) async {
        guard !hasScanned, phase != .scanning else { return }
        await scan(registry: registry)
    }

    public func scan(registry: AppRegistry) async {
        token?.cancel()
        let token = ScanToken()
        self.token = token

        phase = .scanning
        progress = ScanProgress(stage: t("准备中…", "Getting ready…"), fraction: 0, bytesFound: 0)

        await registry.load()
        let context = ScanContext(registry: registry)

        let result = await CleanScanner.scan(context: context, token: token) { update in
            Task { @MainActor [weak self] in
                guard let self, self.token === token else { return }
                self.progress = update
            }
        }

        guard self.token === token, !token.isCancelled else { return }

        categories = result.categories
        blockedApps = result.blockedApps
        progress = nil
        hasScanned = true
        phase = .ready
    }

    public func cancelScan() {
        token?.cancel()
        token = nil
        if phase == .scanning {
            phase = hasScanned ? .ready : .idle
            progress = nil
        }
    }

    // MARK: - Selection

    public func toggle(item itemID: String, in categoryID: CleanCategoryID) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else { return }
        categories[categoryIndex].items[itemIndex].isSelected.toggle()
    }

    public func toggle(category categoryID: CleanCategoryID) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        // Partial always resolves to fully selected: the user reaching for a
        // half-filled box is asking for "all of it" far more often than "none".
        let turnOn = categories[index].selection != .all
        for itemIndex in categories[index].items.indices {
            categories[index].items[itemIndex].isSelected = turnOn
        }
    }

    public func selectAll() {
        for categoryIndex in categories.indices {
            for itemIndex in categories[categoryIndex].items.indices {
                categories[categoryIndex].items[itemIndex].isSelected = true
            }
        }
    }

    public func selectNone() {
        for categoryIndex in categories.indices {
            for itemIndex in categories[categoryIndex].items.indices {
                categories[categoryIndex].items[itemIndex].isSelected = false
            }
        }
    }

    /// Restores the safe default: everything the catalog considers safe, minus
    /// anything held open by a running app.
    public func selectRecommended() {
        for categoryIndex in categories.indices {
            let category = categories[categoryIndex]
            let policy = CleanCatalog.policy(for: category.id)
            for itemIndex in category.items.indices {
                let item = category.items[itemIndex]
                let recommended = policy.selected && item.safety == .safe && item.blockedBy == nil
                categories[categoryIndex].items[itemIndex].isSelected = recommended
            }
        }
    }

    public func toggleExpanded(_ categoryID: CleanCategoryID) {
        if expanded.contains(categoryID) {
            expanded.remove(categoryID)
        } else {
            expanded.insert(categoryID)
        }
    }

    // MARK: - Cleaning

    /// What this run will actually touch.
    ///
    /// Pure, and separated from `clean` on purpose: the interesting behaviour
    /// is "a selected item whose app is running right now is left alone", and
    /// the only way to check that inside `clean` would be to let it delete
    /// something. Given the same categories and the same running set this
    /// answers the same way with no filesystem involved.
    public struct CleanPlan: Sendable {
        public var recyclable: [URL] = []
        public var erasable: [URL] = []
        public var sizes: [URL: Int64] = [:]
        public var skipped: [BlockedApp] = []
    }

    /// - Parameter runningNow: bundle id -> display name, read at the moment
    ///   of the click rather than at the moment of the scan.
    /// `nonisolated` because it touches no actor state: it is a function of
    /// its three arguments and nothing else. That is also what lets a test
    /// call it without hopping to the main actor.
    public nonisolated static func partition(
        categories: [CleanCategory],
        permanentDelete: Bool,
        runningNow: [String: String]
    ) -> CleanPlan {
        var plan = CleanPlan()
        var skipped: [String: Int64] = [:]

        for category in categories {
            for item in category.items where item.isSelected {
                if let bundleID = item.bundleID, let name = runningNow[bundleID] {
                    skipped[name, default: 0] += item.size
                    continue
                }
                plan.sizes[item.url] = item.size
                // The Trash category can only be erased; everything else is
                // recycled unless the user explicitly opted in.
                if category.id.requiresPermanentDeletion || permanentDelete {
                    plan.erasable.append(item.url)
                } else {
                    plan.recyclable.append(item.url)
                }
            }
        }

        plan.skipped = skipped
            .map { BlockedApp(name: $0.key, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }
        return plan
    }

    public func clean(storage: StorageModel, ledger: LedgerModel? = nil) async {
        guard selectedCount > 0, !isBusy else { return }
        phase = .cleaning

        // Who is running *now*, not who was running when the scan ran.
        //
        // `blockedBy` is decided during the scan, and a scan can be minutes
        // old: open the page, go and use Chrome, come back and press the
        // button, and the old answer said Chrome was closed. Re-reading the
        // workspace here costs microseconds and is the only check that is
        // true at the moment the files actually go.
        var runningNow: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier else { continue }
            runningNow[id] = app.localizedName ?? AppRegistry.prettifyBundleID(id)
        }

        let plan = Self.partition(
            categories: categories,
            permanentDelete: permanentDelete,
            runningNow: runningNow
        )
        let recyclable = plan.recyclable
        let erasable = plan.erasable
        let sizes = plan.sizes
        lastSkipped = plan.skipped

        var freed: Int64 = 0
        var trashedCount = 0
        var erasedCount = 0
        var failures = 0

        if !recyclable.isEmpty {
            let outcome = await Removal.trash(recyclable, sizes: sizes)
            freed += outcome.bytes
            trashedCount = outcome.removed.count
            failures += outcome.failed.count + outcome.refused.count
        }

        if !erasable.isEmpty {
            let urls = erasable
            let sizeMap = sizes
            let outcome = await Task.detached(priority: .userInitiated) {
                Removal.deletePermanently(urls, sizes: sizeMap)
            }.value
            freed += outcome.bytes
            erasedCount = outcome.removed.count
            failures += outcome.failed.count + outcome.refused.count
        }

        // Drop what is gone rather than rescanning: a full rescan here would
        // cost as long as the clean itself and would make the result feel
        // like it had not happened.
        let removedPaths = Set(
            (recyclable + erasable).map(\.path)
        )
        // Anything skipped above is not in that set, so it stays in the list
        // — which is what should happen: it is still on disk.
        for categoryIndex in categories.indices {
            categories[categoryIndex].items.removeAll { removedPaths.contains($0.path) }
        }
        categories.removeAll { $0.items.isEmpty }

        lastFailures = failures
        permanentDelete = false
        storage.refresh()
        ledger?.add(bytes: freed, items: trashedCount + erasedCount)
        phase = .finished(bytes: freed, trashed: trashedCount, erased: erasedCount)
    }

    public func dismissResult() {
        if case .finished = phase {
            phase = categories.isEmpty ? .idle : .ready
        }
    }
}
