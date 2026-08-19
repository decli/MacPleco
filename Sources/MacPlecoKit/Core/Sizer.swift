import Foundation

/// A cancellation flag that can be read from any thread.
///
/// Scans are long and users switch sections mid-flight; every walk checks this
/// so abandoned work stops touching the disk instead of finishing quietly.
public final class ScanToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// On-disk size measurement.
///
/// The walking itself lives in `DirectoryWalker`; this is the API the rest of
/// the app calls. Every number quoted here is *allocated* size rather than
/// logical size, because that is the number of bytes a user actually gets
/// back.
public enum Sizer {

    /// Bytes occupied on disk by `url`, following it recursively if it is a
    /// directory. Single-threaded — for one lone item with nothing to share
    /// work with. Prefer `sizes(of:)` when measuring several things at once.
    public static func size(of url: URL, token: ScanToken? = nil) -> Int64 {
        DirectoryWalker.size(of: url.path, token: token)
    }

    /// Sizes many paths, preserving input order.
    ///
    /// Work is pooled across every path rather than run one-task-per-path, so
    /// a single huge directory is finished by the whole pool instead of by one
    /// thread while the others idle.
    public static func sizes(
        of urls: [URL],
        token: ScanToken? = nil,
        maxConcurrent: Int = 8,
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> [Int64] {
        guard !urls.isEmpty else { return [] }

        let collector = ResultCollector(count: urls.count)
        await SizeFanout.measure(
            paths: urls.map(\.path),
            token: token,
            workers: maxConcurrent
        ) { index, bytes in
            let completed = collector.record(index: index, bytes: bytes)
            onProgress?(completed)
        }
        return collector.values
    }

    /// Sizes many paths, delivering each result the moment it lands instead of
    /// holding everything until the batch completes.
    ///
    /// This is what keeps the Space page from sitting blank: small folders
    /// finish in the first fraction of a second and appear immediately, while
    /// the biggest one fills in last — with every worker helping it along.
    public static func streamSizes(
        of urls: [URL],
        token: ScanToken? = nil,
        maxConcurrent: Int = 8,
        onEach: @escaping @Sendable (Int, Int64) -> Void
    ) async {
        guard !urls.isEmpty else { return }
        await SizeFanout.measure(
            paths: urls.map(\.path),
            token: token,
            workers: maxConcurrent,
            onFinish: onEach
        )
    }

    /// Immediate children of a directory, without descending.
    public static func children(of url: URL, includeHidden: Bool = true) -> [URL] {
        let fm = FileManager()
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        ) else {
            return []
        }
        return items
    }
}

/// Order-preserving sink for results that arrive out of order off several
/// threads at once.
private final class ResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int64]
    private var completed = 0

    init(count: Int) {
        storage = [Int64](repeating: 0, count: count)
    }

    /// Returns how many results have landed so far.
    func record(index: Int, bytes: Int64) -> Int {
        lock.lock()
        defer { lock.unlock() }
        storage[index] = bytes
        completed += 1
        return completed
    }

    var values: [Int64] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
