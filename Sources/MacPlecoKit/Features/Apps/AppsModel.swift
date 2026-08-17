import Foundation
import Observation

@Observable
@MainActor
public final class AppsModel {
    public private(set) var isLoading = false
    public init() {}
}
