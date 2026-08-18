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
            await MainActor.run { [weak self] in
                self?.total = total
                self?.available = available
            }
        }
    }
}
