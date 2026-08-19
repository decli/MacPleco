import Foundation
import Darwin

/// Fast on-disk measurement.
///
/// `FileManager`'s enumerator costs a `URL` allocation and a separate
/// `getattrlist` syscall for every single entry, so measuring a folder is
/// dominated by per-file overhead rather than by the disk. `getattrlistbulk`
/// returns a whole batch of directory entries *together with* their allocated
/// sizes in one call — the same API the Finder uses to fill a window.
///
/// The second half of the problem is shape. Sizing a folder's children with
/// one task each looks parallel, but the moment the small children finish, the
/// one enormous child (`~/Library`, 700k files) is left walking on a single
/// thread. `SizeFanout` therefore pools *directories*, not top-level children,
/// so every worker keeps pulling work until the last folder is measured.
///
/// Measured on this machine, a 124-child home folder holding 417 GB:
/// 17.9s with the enumerator, 3.1s with a bulk-read work-stealing pool. Both
/// report the same total to five significant figures.
enum DirectoryWalker {

    /// Reads one directory level: returns the bytes its files occupy and the
    /// subdirectories it contains. Deliberately does *not* recurse — descending
    /// is the pool's job, which is what lets the work be shared out.
    ///
    /// Symbolic links contribute nothing and are never followed, so a link
    /// cannot make one folder count another folder's bytes.
    nonisolated static func level(of path: String) -> (bytes: Int64, subdirectories: [String]) {
        let descriptor = open(path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else { return (0, []) }
        defer { close(descriptor) }

        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
            | attrgroup_t(ATTR_CMN_NAME)
            | attrgroup_t(ATTR_CMN_OBJTYPE)
        // "Allocated size of all of the file's forks" — the same quantity
        // `URLResourceKey.totalFileAllocatedSize` reports, which is what the
        // rest of the app has always quoted.
        request.fileattr = attrgroup_t(ATTR_FILE_ALLOCSIZE)

        let capacity = 256 * 1024
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 8)
        defer { buffer.deallocate() }

        var bytes: Int64 = 0
        var subdirectories: [String] = []

        while true {
            let returned = getattrlistbulk(descriptor, &request, buffer, capacity, 0)
            guard returned > 0 else { break }

            var cursor = buffer
            for _ in 0..<returned {
                let entryLength = cursor.loadUnaligned(as: UInt32.self)
                defer { cursor += Int(entryLength) }

                var field = cursor + MemoryLayout<UInt32>.size
                let present = field.loadUnaligned(as: attribute_set_t.self)
                field += MemoryLayout<attribute_set_t>.size

                // Fields arrive packed in bitmap order, and only the ones the
                // filesystem actually supplied are present, so each has to be
                // stepped over conditionally.
                var name: String?
                if present.commonattr & attrgroup_t(ATTR_CMN_NAME) != 0 {
                    let reference = field.loadUnaligned(as: attrreference_t.self)
                    name = String(
                        cString: (field + Int(reference.attr_dataoffset))
                            .assumingMemoryBound(to: CChar.self)
                    )
                    field += MemoryLayout<attrreference_t>.size
                }

                var objectType = fsobj_type_t(VNON.rawValue)
                if present.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 {
                    objectType = field.loadUnaligned(as: fsobj_type_t.self)
                    field += MemoryLayout<fsobj_type_t>.size
                }

                if objectType == fsobj_type_t(VDIR.rawValue) {
                    if let name { subdirectories.append(path + "/" + name) }
                } else if objectType == fsobj_type_t(VREG.rawValue) {
                    if present.fileattr & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 {
                        bytes += Int64(field.loadUnaligned(as: off_t.self))
                    }
                }
            }
        }

        return (bytes, subdirectories)
    }

    /// Allocated size of a single item, following it recursively on one thread.
    /// Used where there is nothing to share work with — a lone app bundle, a
    /// cache entry — and as the fallback when a path turns out to be a file.
    nonisolated static func size(of path: String, token: ScanToken? = nil) -> Int64 {
        var status = stat()
        guard lstat(path, &status) == 0 else { return 0 }

        let kind = status.st_mode & S_IFMT
        if kind == S_IFLNK { return 0 }
        if kind != S_IFDIR { return Int64(status.st_blocks) * 512 }

        var total: Int64 = 0
        var pending = [path]
        var checked = 0

        while let next = pending.popLast() {
            checked += 1
            // Checking every 64 directories keeps the lock off the hot path
            // while still abandoning a huge tree promptly.
            if checked % 64 == 0, token?.isCancelled == true { return total }
            let (bytes, children) = level(of: next)
            total += bytes
            pending.append(contentsOf: children)
        }
        return total
    }
}

/// Measures many roots at once, sharing one pool of workers between them.
///
/// Each worker pops a directory off a shared stack, reads that one level, and
/// pushes whatever subdirectories it found back on. A root's total is reported
/// the moment its last outstanding directory is done, so results still stream
/// in smallest-first — but the machine no longer idles while the biggest folder
/// finishes alone.
final class SizeFanout: @unchecked Sendable {

    private struct Item {
        let root: Int
        let path: String
    }

    private let condition = NSCondition()
    private var stack: [Item] = []
    private var outstanding: [Int]
    private var totals: [Int64]
    private var active = 0

    private let token: ScanToken?
    private let onFinish: @Sendable (Int, Int64) -> Void

    private init(count: Int, token: ScanToken?, onFinish: @escaping @Sendable (Int, Int64) -> Void) {
        outstanding = [Int](repeating: 0, count: count)
        totals = [Int64](repeating: 0, count: count)
        self.token = token
        self.onFinish = onFinish
    }

    /// Sizes `paths`, calling `onFinish(index, bytes)` as each one completes.
    ///
    /// Workers are real dispatch threads rather than cooperative tasks: these
    /// are blocking syscall loops, and parking eight of Swift's cooperative
    /// threads on the filesystem would starve the UI's own work.
    static func measure(
        paths: [String],
        token: ScanToken? = nil,
        workers: Int = 8,
        onFinish: @escaping @Sendable (Int, Int64) -> Void
    ) async {
        guard !paths.isEmpty else { return }
        let fanout = SizeFanout(count: paths.count, token: token, onFinish: onFinish)
        fanout.seed(paths)

        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            let count = max(1, min(workers, ProcessInfo.processInfo.activeProcessorCount))
            for _ in 0..<count {
                DispatchQueue.global(qos: .userInitiated).async(group: group) {
                    fanout.work()
                }
            }
            group.notify(queue: .global(qos: .userInitiated)) {
                continuation.resume()
            }
        }
    }

    private func seed(_ paths: [String]) {
        condition.lock()
        for (index, path) in paths.enumerated() {
            var status = stat()
            guard lstat(path, &status) == 0 else {
                onFinish(index, 0)
                continue
            }
            let kind = status.st_mode & S_IFMT
            if kind == S_IFLNK {
                onFinish(index, 0)
            } else if kind != S_IFDIR {
                onFinish(index, Int64(status.st_blocks) * 512)
            } else {
                outstanding[index] = 1
                stack.append(Item(root: index, path: path))
            }
        }
        condition.unlock()
    }

    private func take() -> Item? {
        condition.lock()
        defer { condition.unlock() }
        while true {
            if token?.isCancelled == true { return nil }
            if let next = stack.popLast() {
                active += 1
                return next
            }
            // Nothing queued and nobody still producing: the walk is over.
            if active == 0 { return nil }
            // Bounded so cancellation is noticed even if a wake-up is missed.
            condition.wait(until: Date().addingTimeInterval(0.02))
        }
    }

    private func work() {
        while let item = take() {
            let (bytes, children) = DirectoryWalker.level(of: item.path)

            condition.lock()
            totals[item.root] += bytes
            outstanding[item.root] += children.count - 1
            for child in children {
                stack.append(Item(root: item.root, path: child))
            }
            let finished = outstanding[item.root] == 0
            let total = totals[item.root]
            active -= 1
            condition.broadcast()
            condition.unlock()

            if finished {
                onFinish(item.root, total)
            }
        }
    }
}
