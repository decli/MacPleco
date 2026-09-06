import Foundation
import Observation

/// Capacity of the boot volume.
///
/// `volumeAvailableCapacityForImportantUsage` is the number Finder shows: it
/// counts space macOS would free by evicting purgeable caches and local
/// snapshots. Reporting the raw free-block count instead would tell users they
/// have far less room than the system believes, which reads as alarmism.
@Observable
@MainActor
public final class StorageModel {
    public private(set) var total: Int64 = 0
    public private(set) var available: Int64 = 0

    /// How many Time Machine local snapshots the boot volume is holding.
    ///
    /// This is the honest answer to "why don't the folder sizes add up to the
    /// used space?". A snapshot pins the blocks of files that have since been
    /// deleted or rewritten. Those blocks are charged to the volume but belong
    /// to no folder any more, so no directory walk can find them — and the
    /// free-space figure above already discounts them, because macOS will
    /// evict snapshots when it needs the room. Two true numbers that cannot be
    /// reconciled without saying this out loud.
    public private(set) var localSnapshots: Int = 0

    public var used: Int64 { max(0, total - available) }

    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    public init() {}

    /// The important-usage key is an XPC-backed purgeable-space query, not a
    /// statfs read — it can take tens of milliseconds. Off the main thread,
    /// same as the permissions probe, so opening the menu bar panel never
    /// hitches on it.
    public func refresh() {
        Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            guard let values = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ]) else { return }

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            let snapshots = Self.localSnapshotCount()
            await MainActor.run { [weak self] in
                self?.total = total
                self?.available = available
                self?.localSnapshots = snapshots
            }
        }
    }

    /// Counts local snapshots via `tmutil`.
    ///
    /// `tmutil listlocalsnapshots /` needs no privileges and no entitlement —
    /// it is the same listing Disk Utility shows. Anything unexpected (tmutil
    /// missing, a non-zero exit, output in a shape we do not recognise) counts
    /// as zero, which hides the explanation rather than inventing a number.
    nonisolated static func localSnapshotCount() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return 0 }

        return countSnapshotLines(String(decoding: data, as: UTF8.self))
    }

    /// Split out from the `tmutil` call so the parsing can be checked without
    /// a Mac that happens to have snapshots on it.
    ///
    /// The first line is a header ("Snapshots for disk /:"); every snapshot
    /// line carries the reverse-DNS prefix, so it matches on that rather than
    /// on line position — the header wording has changed between macOS
    /// releases and counting "all lines but the first" would follow it.
    public nonisolated static func countSnapshotLines(_ output: String) -> Int {
        output
            .split(separator: "\n")
            .filter { $0.contains("com.apple.TimeMachine") }
            .count
    }
}
