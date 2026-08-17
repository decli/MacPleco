import Foundation
import Observation

@Observable
@MainActor
public final class SpaceModel {
    public private(set) var isScanning = false
    public init() {}
}
