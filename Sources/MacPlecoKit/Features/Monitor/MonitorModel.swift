import Foundation
import Observation

@Observable
@MainActor
public final class MonitorModel {

    public private(set) var cpuUser: Double = 0
    public private(set) var cpuSystem: Double = 0
    public private(set) var memory = MemorySample()
    public private(set) var networkIn: Double = 0
    public private(set) var networkOut: Double = 0
    public private(set) var processes: [ProcessSample] = []

    /// Rolling windows for the sparklines, newest last.
    public private(set) var cpuHistory: [Double] = []
    public private(set) var memoryHistory: [Double] = []
    public private(set) var networkHistory: [Double] = []

    public private(set) var isStreaming = false

    private let sampler = MetricsSampler()
    private var loop: Task<Void, Never>?
    private var tick = 0

    private let historyLength = 70

    public init() {}

    /// Sampling only runs while the Monitor section is on screen. A cleaner
    /// that quietly burns CPU polling counters in the background would be
    /// undermining its own point.
    public func start() {
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
        loop?.cancel()
        loop = nil
        isStreaming = false
    }

    private func sample() async {
        let cpu = sampler.sampleCPU()
        cpuUser = cpu.user
        cpuSystem = cpu.system
        memory = sampler.sampleMemory()

        let network = sampler.sampleNetwork()
        networkIn = network.received
        networkOut = network.sent

        append(&cpuHistory, cpu.user + cpu.system)
        append(&memoryHistory, memory.usedFraction)
        append(&networkHistory, network.received + network.sent)

        // The process list changes far more slowly than the counters and costs
        // a subprocess each time, so it refreshes every third tick.
        tick += 1
        if tick % 3 == 1 {
            processes = await Task.detached(priority: .utility) {
                MetricsSampler.sampleProcesses()
            }.value
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
