import Foundation
import Observation

public enum ProcessSortMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case started
    case name

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return t("内存", "Memory")
        case .started: return t("启动", "Started")
        case .name: return t("进程", "Process")
        }
    }

    /// The direction that answers the question the column is usually asked.
    /// "Busiest" means most CPU, but "started" means most recently launched.
    var defaultsToAscending: Bool {
        self == .name
    }
}

public enum ProcessOrderMode: String, CaseIterable, Identifiable, Sendable, TitledChoice {
    case live
    case fixed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .live: return t("实时排序", "Live order")
        case .fixed: return t("固定位置", "Fixed positions")
        }
    }
}

/// Which processes to show.
///
/// The split exists because the two groups answer different questions: "which
/// of my apps is eating the battery" and "what is macOS doing in the
/// background". Mixed together, the system's dozens of daemons bury the
/// handful of rows a person can actually act on.
public enum ProcessScope: String, CaseIterable, Identifiable, Sendable, TitledChoice {
    case all
    case apps
    case system

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return t("全部", "All")
        case .apps: return t("应用", "Apps")
        case .system: return t("系统", "System")
        }
    }

    func admits(_ process: ProcessSample) -> Bool {
        switch self {
        case .all: return true
        case .apps: return !process.isSystem
        case .system: return process.isSystem
        }
    }
}

@Observable
@MainActor
public final class MonitorModel {

    public private(set) var cpuUser: Double = 0
    public private(set) var cpuSystem: Double = 0
    public private(set) var coreLoads: [Double] = []
    public private(set) var memory = MemorySample()
    public private(set) var networkIn: Double = 0
    public private(set) var networkOut: Double = 0
    public private(set) var gpu = GPUSample()
    public private(set) var processes: [ProcessSample] = []

    public var processSort: ProcessSortMetric = .cpu {
        didSet {
            guard processSort != oldValue else { return }
            sortAscending = processSort.defaultsToAscending
            rebuildProcessList(reseedFixed: true)
        }
    }

    /// Clicking the active column header flips it, which is how every table on
    /// this platform behaves.
    public var sortAscending = false {
        didSet { rebuildProcessList(reseedFixed: true) }
    }

    public var processOrder: ProcessOrderMode = .live {
        didSet { rebuildProcessList(reseedFixed: processOrder == .fixed) }
    }

    public var scope: ProcessScope = .all {
        didSet { rebuildProcessList(reseedFixed: true) }
    }

    /// Matches process name, executable path or pid.
    public var query = "" {
        didSet { rebuildProcessList(reseedFixed: true) }
    }

    /// The result of the last force-quit, shown briefly beside the table.
    public var lastOutcome: (message: String, succeeded: Bool)?

    /// Rolling windows for the sparklines, newest last. User and system CPU are
    /// kept apart, and so are download and upload, because a single blended
    /// line cannot be read back into its parts.
    public private(set) var cpuUserHistory: [Double] = []
    public private(set) var cpuSystemHistory: [Double] = []
    public private(set) var memoryHistory: [Double] = []
    public private(set) var networkInHistory: [Double] = []
    public private(set) var networkOutHistory: [Double] = []
    public private(set) var gpuHistory: [Double] = []

    public private(set) var isStreaming = false

    private let sampler = MetricsSampler()
    private var loop: Task<Void, Never>?
    private var tick = 0
    private var rawProcesses: [ProcessSample] = []
    private var fixedProcessIDs: [Int32] = []

    private let historyLength = 70
    private let restingLimit = 12
    private let searchingLimit = 40

    public init() {}

    /// A search is a request to see everything that matches, not the top
    /// twelve of it.
    private var processLimit: Int {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? restingLimit : searchingLimit
    }

    public var matchCount: Int {
        filtered(rawProcesses).count
    }

    /// Sampling only runs while something is watching — the Monitor section or
    /// the menu bar panel. Reference-counted, because both can be open at once
    /// and closing the panel must not freeze the page's charts.
    private var watchers = 0

    public func start() {
        watchers += 1
        guard loop == nil else { return }
        isStreaming = true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }

    public func stop() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        loop?.cancel()
        loop = nil
        isStreaming = false
    }

    private func sample() async {
        let cpu = sampler.sampleCPU()
        cpuUser = cpu.user
        cpuSystem = cpu.system
        coreLoads = sampler.samplePerCoreCPU()
        memory = sampler.sampleMemory()

        let network = sampler.sampleNetwork()
        networkIn = network.received
        networkOut = network.sent

        let graphics = MetricsSampler.sampleGPU()
        gpu = graphics

        append(&cpuUserHistory, cpu.user)
        append(&cpuSystemHistory, cpu.system)
        append(&memoryHistory, memory.usedFraction)
        append(&networkInHistory, network.received)
        append(&networkOutHistory, network.sent)
        append(&gpuHistory, graphics.device ?? 0)

        // Activity Monitor defaults to a five-second cadence. Three seconds is
        // responsive enough to watch a process move without burning CPU just
        // to report CPU usage.
        tick += 1
        if tick % 2 == 1 {
            let snapshot = await Task.detached(priority: .utility) {
                MetricsSampler.sampleProcesses()
            }.value
            applyProcessSnapshot(snapshot)
        }
    }

    private func applyProcessSnapshot(_ snapshot: [ProcessSample]) {
        rawProcesses = snapshot
        rebuildProcessList(reseedFixed: false)
    }

    // MARK: - Ending a process

    /// Ends a process and refreshes the table so the row disappears rather
    /// than lingering as a ghost until the next sample.
    public func end(_ process: ProcessSample, force: Bool) async {
        let outcome = ProcessControl.end(pid: process.pid, force: force)
        lastOutcome = (
            outcome.succeeded
                ? t("\(process.name)：\(outcome.message)", "\(process.name): \(outcome.message)")
                : outcome.message,
            outcome.succeeded
        )

        guard outcome.succeeded else { return }
        // A graceful quit is not instant; give it a moment before re-reading.
        try? await Task.sleep(for: .milliseconds(force ? 150 : 600))
        let snapshot = await Task.detached(priority: .userInitiated) {
            MetricsSampler.sampleProcesses()
        }.value
        fixedProcessIDs.removeAll { $0 == process.pid }
        applyProcessSnapshot(snapshot)
    }

    public func clearOutcome() {
        lastOutcome = nil
    }

    // MARK: - List assembly

    private func filtered(_ samples: [ProcessSample]) -> [ProcessSample] {
        var result = samples.filter { scope.admits($0) }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return result }

        result = result.filter { process in
            process.name.localizedCaseInsensitiveContains(trimmed)
                || process.path.localizedCaseInsensitiveContains(trimmed)
                || String(process.pid).hasPrefix(trimmed)
        }
        return result
    }

    /// Live mode re-sorts every snapshot. Fixed mode keeps existing rows in
    /// place, removes processes that exited, and fills empty slots with the
    /// busiest newcomers. Changing metric, direction, scope or search
    /// deliberately takes one fresh sort before freezing the new order.
    private func rebuildProcessList(reseedFixed: Bool) {
        let sorted = sortedProcesses(filtered(rawProcesses))
        let limit = processLimit

        guard processOrder == .fixed, !reseedFixed else {
            processes = Array(sorted.prefix(limit))
            fixedProcessIDs = processOrder == .fixed ? processes.map(\.pid) : []
            return
        }

        let admitted = Dictionary(sorted.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var ids = fixedProcessIDs.filter { admitted[$0] != nil }
        let retained = Set(ids)
        ids.append(contentsOf: sorted.lazy.map(\.pid).filter { !retained.contains($0) })
        fixedProcessIDs = Array(ids.prefix(limit))
        processes = fixedProcessIDs.compactMap { admitted[$0] }
    }

    private func sortedProcesses(_ samples: [ProcessSample]) -> [ProcessSample] {
        samples.sorted { lhs, rhs in
            let ordered: Bool
            switch processSort {
            case .cpu:
                if lhs.cpu == rhs.cpu { return tieBreak(lhs, rhs) }
                ordered = lhs.cpu > rhs.cpu
            case .memory:
                if lhs.memory == rhs.memory { return tieBreak(lhs, rhs) }
                ordered = lhs.memory > rhs.memory
            case .started:
                let left = lhs.started ?? .distantPast
                let right = rhs.started ?? .distantPast
                if left == right { return tieBreak(lhs, rhs) }
                ordered = left > right
            case .name:
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                if comparison == .orderedSame { return lhs.pid < rhs.pid }
                // `.name` defaults to ascending, so its natural order is
                // already A→Z; the flag below flips it like the others.
                ordered = comparison == .orderedDescending
            }
            return sortAscending ? !ordered : ordered
        }
    }

    private func tieBreak(_ lhs: ProcessSample, _ rhs: ProcessSample) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func append(_ series: inout [Double], _ value: Double) {
        series.append(value)
        if series.count > historyLength {
            series.removeFirst(series.count - historyLength)
        }
    }

    public var cpuTotal: Double { min(1, cpuUser + cpuSystem) }
}
