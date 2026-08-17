import Foundation
import Observation

@Observable
@MainActor
public final class TuneModel {
    public let tasks: [TuneTask] = TuneCatalog.tasks

    public private(set) var isRunning = false
    public private(set) var runningTaskID: String?
    public private(set) var results: [String: TuneResult] = [:]

    /// Nothing is pre-selected. These are repairs for specific symptoms, not
    /// routine hygiene, and running all of them because they were ticked by
    /// default would restart the Finder on someone who just wanted to flush
    /// their DNS.
    public var selected: Set<String> = []

    public init() {}

    public var selectedCount: Int { selected.count }

    public func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    public func runSelected() async {
        guard !selected.isEmpty, !isRunning else { return }
        isRunning = true
        results = results.filter { !selected.contains($0.key) }

        for task in tasks where selected.contains(task.id) {
            runningTaskID = task.id
            let result = await TuneRunner.run(task)
            results[task.id] = result
        }

        runningTaskID = nil
        isRunning = false
        selected = []
    }

    public func run(_ task: TuneTask) async {
        guard !isRunning else { return }
        isRunning = true
        runningTaskID = task.id
        results[task.id] = await TuneRunner.run(task)
        runningTaskID = nil
        isRunning = false
    }
}
