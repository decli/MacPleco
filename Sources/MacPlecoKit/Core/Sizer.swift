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
public enum Sizer {

    private static let sizeKeys: [URLResourceKey] = [
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]

    /// Bytes actually occupied on disk by `url`, following it recursively if it
    /// is a directory.
    ///
    /// Reports *allocated* size rather than logical size: that is the number of
    /// bytes a user gets back, which is the only number this app should quote.
    public static func size(of url: URL, token: ScanToken? = nil) -> Int64 {
        let fm = FileManager()

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return allocatedSize(of: url)
        }

        // The enumerator does not descend into symlinked directories, which
        // keeps cycles impossible and stops one cache counting another's bytes.
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: sizeKeys,
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        var checked = 0
        for case let child as URL in enumerator {
            checked += 1
            // Checking every 512 entries keeps the lock out of the hot path
            // while still aborting a huge tree promptly.
            if checked % 512 == 0, token?.isCancelled == true { return total }
            total += allocatedSize(of: child)
        }
        return total
    }

    private static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(sizeKeys)) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if let total = values.totalFileAllocatedSize { return Int64(total) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        return 0
    }

    /// Sizes many paths concurrently, preserving input order.
    ///
    /// Concurrency is capped rather than unbounded: these are blocking disk
    /// walks, and handing four hundred of them to the cooperative pool at once
    /// starves every other task in the app, including the UI's own.
    public static func sizes(
        of urls: [URL],
        token: ScanToken? = nil,
        maxConcurrent: Int = 6,
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> [Int64] {
        guard !urls.isEmpty else { return [] }
        var results = [Int64](repeating: 0, count: urls.count)
        var completed = 0
        var next = 0

        await withTaskGroup(of: (Int, Int64).self) { group in
            let window = min(maxConcurrent, urls.count)
            while next < window {
                let index = next
                let url = urls[index]
                group.addTask { (index, size(of: url, token: token)) }
                next += 1
            }

            while let (index, value) = await group.next() {
                results[index] = value
                completed += 1
                onProgress?(completed)

                if token?.isCancelled == true { break }
                if next < urls.count {
                    let index = next
                    let url = urls[index]
                    group.addTask { (index, size(of: url, token: token)) }
                    next += 1
                }
            }
            group.cancelAll()
        }
        return results
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
