import Foundation
import Observation

public enum ProcessSortMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case gpu
    case memory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return t("内存", "Memory")
        }
    }
}

public enum ProcessOrderMode: String, CaseIterable, Identifiable, Sendable {
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

@Observable
@MainActor
public final class MonitorModel {

    public private(set) var cpuUser: Double = 0
    public private(set) var cpuSystem: Double = 0
    public private(set) var coreLoads: [Double] = []
    public private(set) var memory = MemorySample()
    public private(set) var networkIn: Double = 0
    public private(set) var networkOut: Double = 0
    public private(set) var processes: [ProcessSample] = []

    public var processSort: ProcessSortMetric = .cpu {
        didSet { rebuildProcessList(reseedFixed: true) }
    }
    public var processOrder: ProcessOrderMode = .live {
        didSet { rebuildProcessList(reseedFixed: processOrder == .fixed) }
    }

    /// `nil` GPU readings are intentional rather than a sampling failure: the
    /// public APIs available to a normal Mac app do not expose other apps'
    /// real-time GPU percentages. The UI explains this instead of fabricating
    /// a number or asking for administrator access.
    public var hasPerProcessGPU: Bool {
        rawProcesses.contains { $0.gpu != nil }
    }

    /// Rolling windows for the sparklines, newest last.
    public private(set) var cpuHistory: [Double] = []
    public private(set) var memoryHistory: [Double] = []
    public private(set) var networkHistory: [Double] = []

    public private(set) var isStreaming = false

    private let sampler = MetricsSampler()
    private var loop: Task<Void, Never>?
    private var tick = 0
    private var rawProcesses: [ProcessSample] = []
    private var fixedProcessIDs: [Int32] = []

    private let historyLength = 70
    private let processLimit = 12

    public init() {}

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

        append(&cpuHistory, cpu.user + cpu.system)
        append(&memoryHistory, memory.usedFraction)
        append(&networkHistory, network.received + network.sent)

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

    /// Live mode re-sorts every snapshot. Fixed mode keeps existing rows in
    /// place, removes processes that exited, and fills empty slots with the
    /// busiest newcomers. Switching metric deliberately takes one fresh sort
    /// before freezing the new order.
    private func rebuildProcessList(reseedFixed: Bool) {
        let sorted = sortedProcesses(rawProcesses)

        guard processOrder == .fixed, !reseedFixed else {
            processes = Array(sorted.prefix(processLimit))
            fixedProcessIDs = processOrder == .fixed ? processes.map(\.pid) : []
            return
        }

        let byPID = Dictionary(uniqueKeysWithValues: rawProcesses.map { ($0.pid, $0) })
        var ids = fixedProcessIDs.filter { byPID[$0] != nil }
        let retained = Set(ids)
        ids.append(contentsOf: sorted.lazy.map(\.pid).filter { !retained.contains($0) })
        fixedProcessIDs = Array(ids.prefix(processLimit))
        processes = fixedProcessIDs.compactMap { byPID[$0] }
    }

    private func sortedProcesses(_ samples: [ProcessSample]) -> [ProcessSample] {
        samples.sorted { lhs, rhs in
            switch processSort {
            case .cpu:
                if lhs.cpu != rhs.cpu { return lhs.cpu > rhs.cpu }
            case .memory:
                if lhs.memory != rhs.memory { return lhs.memory > rhs.memory }
            case .gpu:
                switch (lhs.gpu, rhs.gpu) {
                case let (left?, right?) where left != right:
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    break
                }
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func append(_ series: inout [Double], _ value: Double) {
        series.append(value)
        if series.count > historyLength {
            series.removeFirst(series.count - historyLength)
        }
    }

    public var cpuTotal: Double { min(1, cpuUser + cpuSystem) }
}
