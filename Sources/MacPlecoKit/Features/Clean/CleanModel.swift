import Foundation
import Observation

@Observable
@MainActor
public final class CleanModel {
    public private(set) var isScanning = false
    public private(set) var reclaimable: Int64 = 0
    public private(set) var hasScanned = false

    public init() {}

    public func scanIfNeeded() async {
        guard !hasScanned, !isScanning else { return }
        await scan()
    }

    public func scan() async {
        isScanning = true
        defer {
            isScanning = false
            hasScanned = true
        }
    }
}
