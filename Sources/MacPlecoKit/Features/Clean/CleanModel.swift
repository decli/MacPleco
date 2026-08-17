import Foundation
import Observation

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

    public func clean(storage: StorageModel) async {
        guard selectedCount > 0, !isBusy else { return }
        phase = .cleaning

        // The Trash category can only be erased; everything else is recycled
        // unless the user explicitly opted into permanent deletion.
        var recyclable: [URL] = []
        var erasable: [URL] = []
        var sizes: [URL: Int64] = [:]

        for category in categories {
            for item in category.items where item.isSelected {
                sizes[item.url] = item.size
                if category.id.requiresPermanentDeletion || permanentDelete {
                    erasable.append(item.url)
                } else {
                    recyclable.append(item.url)
                }
            }
        }

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
        for categoryIndex in categories.indices {
            categories[categoryIndex].items.removeAll { removedPaths.contains($0.path) }
        }
        categories.removeAll { $0.items.isEmpty }

        lastFailures = failures
        permanentDelete = false
        storage.refresh()
        phase = .finished(bytes: freed, trashed: trashedCount, erased: erasedCount)
    }

    public func dismissResult() {
        if case .finished = phase {
            phase = categories.isEmpty ? .idle : .ready
        }
    }
}
