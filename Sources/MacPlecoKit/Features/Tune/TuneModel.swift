import Foundation
import Observation

@Observable
@MainActor
public final class TuneModel {
    public private(set) var isRunning = false
    public init() {}
}
