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

public struct LargeFile: Identifiable, Sendable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let size: Int64
    public let modified: Date?

    public var folder: String {
        url.deletingLastPathComponent().lastPathComponent
    }
}

@Observable
@MainActor
public final class SpaceModel {

    public enum Tab: String, CaseIterable, Identifiable {
        case map
        case large

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .map: return t("空间地图", "Space map")
            case .large: return t("大文件", "Large files")
            }
        }
    }

    public var tab: Tab = .map

    // MARK: - Map state

    public private(set) var entries: [SpaceEntry] = []
    public private(set) var isScanning = false
    public private(set) var scanned = 0
    public private(set) var expected = 0

    /// Breadcrumb trail. The first element is always the scan root.
    public private(set) var trail: [SpaceEntry] = []

    /// Directory listings already measured this session. Walking back up a
    /// breadcrumb, or re-entering a folder, paints instantly from here; the
    /// refresh button clears it.
    private var levelCache: [String: [SpaceEntry]] = [:]

    public var currentURL: URL {
        trail.last?.url ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    public var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }

    private var token: ScanToken?

    public init() {}

    // MARK: - Map scanning

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
        levelCache.removeValue(forKey: currentURL.path)
        await scanCurrent()
    }

    private func scanCurrent() async {
        token?.cancel()
        let token = ScanToken()
        self.token = token

        let root = currentURL

        if let cached = levelCache[root.path] {
            entries = cached
            isScanning = false
            scanned = cached.count
            expected = cached.count
            return
        }

        isScanning = true
        entries = []
        scanned = 0

        let children = Sizer.children(of: root)
        var descriptors: [(URL, String, Bool)] = []
        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            descriptors.append((child, child.lastPathComponent, values?.isDirectory ?? false))
        }
        expected = descriptors.count

        // Results land one at a time, sorted into place, so the map assembles
        // in front of the user instead of appearing after the slowest walk.
        let snapshot = descriptors
        await Sizer.streamSizes(of: snapshot.map(\.0), token: token, maxConcurrent: 10) { index, size in
            Task { @MainActor [weak self] in
                guard let self, self.token === token else { return }
                self.scanned += 1
                guard size > 0 else { return }
                let descriptor = snapshot[index]
                let entry = SpaceEntry(
                    url: descriptor.0,
                    name: descriptor.1,
                    isDirectory: descriptor.2,
                    size: size
                )
                let position = self.entries.firstIndex { $0.size < size } ?? self.entries.endIndex
                self.entries.insert(entry, at: position)
            }
        }

        guard self.token === token, !token.isCancelled else { return }
        isScanning = false
        levelCache[root.path] = entries
    }

    // MARK: - Large files

    public private(set) var largeFiles: [LargeFile] = []
    public private(set) var isScanningLarge = false
    public private(set) var largeFilesScanned = 0
    public private(set) var hasScannedLarge = false

    private var largeToken: ScanToken?

    public func scanLargeIfNeeded() async {
        guard !hasScannedLarge, !isScanningLarge else { return }
        await scanLarge()
    }

    public func scanLarge() async {
        largeToken?.cancel()
        let token = ScanToken()
        largeToken = token

        isScanningLarge = true
        largeFiles = []
        largeFilesScanned = 0

        let found = await Task.detached(priority: .userInitiated) {
            LargeFileScanner.scan(token: token) { count in
                Task { @MainActor [weak self] in
                    guard let self, self.largeToken === token else { return }
                    self.largeFilesScanned = count
                }
            }
        }.value

        guard largeToken === token, !token.isCancelled else { return }
        largeFiles = found
        isScanningLarge = false
        hasScannedLarge = true
    }

    // MARK: - Removal

    /// Trashes something the user picked out by hand.
    public func trash(_ entry: SpaceEntry, storage: StorageModel) async -> Bool {
        let outcome = await Removal.trash(
            [entry.url],
            sizes: [entry.url: entry.size],
            policy: .userSelected
        )
        guard !outcome.removed.isEmpty else { return false }
        entries.removeAll { $0.id == entry.id }
        levelCache[currentURL.path] = entries
        storage.refresh()
        return true
    }

    public func trashLargeFile(_ file: LargeFile, storage: StorageModel) async -> Bool {
        let outcome = await Removal.trash(
            [file.url],
            sizes: [file.url: file.size],
            policy: .userSelected
        )
        guard !outcome.removed.isEmpty else { return false }
        largeFiles.removeAll { $0.id == file.id }
        storage.refresh()
        return true
    }

    public func canTrash(_ url: URL) -> Bool {
        SafePath.isUserDeletable(url)
    }
}

// MARK: - Large file scanner

/// Finds the big files a person can actually act on.
///
/// Scope is deliberately the *visible* home folder: Documents, Downloads,
/// Desktop, Movies and friends. Hidden folders are skipped because everything
/// disposable in them is already the Clean section's job, and everything else
/// in them (model weights, package stores) is a trap for exactly the user this
/// page serves.
enum LargeFileScanner {
    static let threshold: Int64 = 100 * 1000 * 1000   // 100 MB, decimal like Finder
    static let keepTop = 120

    nonisolated static func scan(
        token: ScanToken,
        onProgress: @escaping @Sendable (Int) -> Void
    ) -> [LargeFile] {
        let fm = FileManager()
        let home = URL(fileURLWithPath: NSHomeDirectory())

        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: [
                .isRegularFileKey, .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey, .contentModificationDateKey, .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var results: [LargeFile] = []
        var visited = 0

        for case let url as URL in enumerator {
            visited += 1
            if visited % 512 == 0 {
                if token.isCancelled { break }
                onProgress(visited)
            }

            let name = url.lastPathComponent
            // Application bundles belong to the Apps section; the user's own
            // apps folder is the only non-hidden root worth pruning.
            if name == "Applications", enumerator.level == 1 {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey, .contentModificationDateKey, .isSymbolicLinkKey
            ]) else { continue }

            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= threshold else { continue }
            guard SafePath.isUserDeletable(url) else { continue }

            results.append(
                LargeFile(url: url, name: name, size: size, modified: values.contentModificationDate)
            )
        }

        onProgress(visited)
        results.sort { $0.size > $1.size }
        if results.count > keepTop {
            results.removeSubrange(keepTop...)
        }
        return results
    }
}
