import Foundation
import Observation

public struct SpaceEntry: Identifiable, Sendable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public var size: Int64

    public var displayPath: String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

@Observable
@MainActor
public final class SpaceModel {

    public private(set) var entries: [SpaceEntry] = []
    public private(set) var isScanning = false
    public private(set) var scanned = 0
    public private(set) var expected = 0

    /// Breadcrumb trail. The first element is always the scan root.
    public private(set) var trail: [SpaceEntry] = []

    public var currentURL: URL {
        trail.last?.url ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    public var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }

    private var token: ScanToken?

    public init() {}

    // MARK: - Scanning

    public func start() async {
        guard trail.isEmpty else { return }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        trail = [
            SpaceEntry(url: home, name: t("个人文件夹", "Home"), isDirectory: true, size: 0)
        ]
        await scanCurrent()
    }

    public func enter(_ entry: SpaceEntry) async {
        guard entry.isDirectory else { return }
        trail.append(entry)
        await scanCurrent()
    }

    public func goTo(index: Int) async {
        guard index < trail.count - 1 else { return }
        trail = Array(trail.prefix(index + 1))
        await scanCurrent()
    }

    public func refresh() async {
        await scanCurrent()
    }

    private func scanCurrent() async {
        token?.cancel()
        let token = ScanToken()
        self.token = token

        isScanning = true
        entries = []
        scanned = 0

        let root = currentURL
        let children = Sizer.children(of: root)
        expected = children.count

        // Directories are sized recursively; files report their own size, so
        // the map always sums to what the enclosing folder actually occupies.
        var descriptors: [(URL, String, Bool)] = []
        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            descriptors.append((child, child.lastPathComponent, values?.isDirectory ?? false))
        }

        let sizes = await Sizer.sizes(
            of: descriptors.map(\.0),
            token: token,
            maxConcurrent: 6
        ) { [weak self] done in
            Task { @MainActor in
                guard let self, self.token === token else { return }
                self.scanned = done
            }
        }

        guard self.token === token, !token.isCancelled else { return }
        guard sizes.count == descriptors.count else {
            isScanning = false
            return
        }

        var built: [SpaceEntry] = []
        for (index, descriptor) in descriptors.enumerated() {
            let size = sizes[index]
            guard size > 0 else { continue }
            built.append(
                SpaceEntry(
                    url: descriptor.0,
                    name: descriptor.1,
                    isDirectory: descriptor.2,
                    size: size
                )
            )
        }

        entries = built.sorted { $0.size > $1.size }
        isScanning = false
    }

    // MARK: - Removal

    /// Trashes something the user picked out of the map by hand.
    public func trash(_ entry: SpaceEntry, storage: StorageModel) async -> Bool {
        let outcome = await Removal.trash(
            [entry.url],
            sizes: [entry.url: entry.size],
            policy: .userSelected
        )
        guard !outcome.removed.isEmpty else { return false }
        entries.removeAll { $0.id == entry.id }
        storage.refresh()
        return true
    }

    public func canTrash(_ entry: SpaceEntry) -> Bool {
        SafePath.isUserDeletable(entry.url)
    }
}
