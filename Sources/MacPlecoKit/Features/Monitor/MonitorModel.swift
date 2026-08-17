import Foundation
import Observation

@Observable
@MainActor
public final class MonitorModel {
    public private(set) var isStreaming = false
    public init() {}
}
