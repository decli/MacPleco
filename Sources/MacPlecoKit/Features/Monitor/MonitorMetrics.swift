import Foundation
import Darwin

public struct MemorySample: Sendable {
    public var total: Int64 = 0
    public var used: Int64 = 0
    public var wired: Int64 = 0
    public var compressed: Int64 = 0
    public var cached: Int64 = 0

    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }
}

public struct ProcessSample: Identifiable, Sendable, Hashable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpu: Double
    public let memory: Int64
}

/// Live system counters.
///
/// CPU and memory come from Mach, which reports cumulative tick counts, so the
/// sampler holds the previous reading and reports the delta — an instantaneous
/// read of those counters would describe the machine since boot, not now.
public final class MetricsSampler {

    private var lastCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var lastNetwork: (received: UInt64, sent: UInt64, at: Date)?

    private let pageSize: Int64

    public init() {
        pageSize = SystemInfo.sysctlInt("hw.pagesize") ?? 16_384
    }

    // MARK: - CPU

    /// Returns the share of CPU time spent in user and system code since the
    /// previous call, each 0...1 across all cores.
    public func sampleCPU() -> (user: Double, system: Double) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }

        let ticks = (
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
        defer { lastCPUTicks = ticks }

        guard let previous = lastCPUTicks else { return (0, 0) }

        let userDelta = Double(ticks.user &- previous.user) + Double(ticks.nice &- previous.nice)
        let systemDelta = Double(ticks.system &- previous.system)
        let idleDelta = Double(ticks.idle &- previous.idle)
        let total = userDelta + systemDelta + idleDelta

        guard total > 0 else { return (0, 0) }
        return (userDelta / total, systemDelta / total)
    }

    // MARK: - Per-core CPU

    private var lastPerCoreTicks: [[UInt64]] = []

    /// Load per logical core since the previous call, each 0...1.
    public func samplePerCoreCPU() -> [Double] {
        var coreCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &coreCount,
            &infoArray,
            &infoCount
        )
        guard result == KERN_SUCCESS, let infoArray else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: infoArray)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let states = Int(CPU_STATE_MAX)
        var loads: [Double] = []
        var current: [[UInt64]] = []

        for core in 0..<Int(coreCount) {
            let base = core * states
            let user = UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_SYSTEM)]))
            let idle = UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_IDLE)]))
            let nice = UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_NICE)]))
            current.append([user, system, idle, nice])

            if core < lastPerCoreTicks.count {
                let previous = lastPerCoreTicks[core]
                let busy = Double(user &- previous[0])
                    + Double(system &- previous[1])
                    + Double(nice &- previous[3])
                let total = busy + Double(idle &- previous[2])
                loads.append(total > 0 ? min(1, busy / total) : 0)
            } else {
                loads.append(0)
            }
        }

        lastPerCoreTicks = current
        return loads
    }

    // MARK: - Memory

    public func sampleMemory() -> MemorySample {
        var sample = MemorySample()
        sample.total = SystemInfo.physicalMemory

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return sample }

        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize
        let appMemory = (Int64(stats.internal_page_count) - Int64(stats.purgeable_count)) * pageSize

        sample.wired = wired
        sample.compressed = compressed
        sample.cached = Int64(stats.external_page_count) * pageSize
        // Matches how Activity Monitor adds up "Memory Used".
        sample.used = max(0, appMemory + wired + compressed)
        return sample
    }

    // MARK: - Network

    /// Bytes per second across every non-loopback interface.
    public func sampleNetwork() -> (received: Double, sent: Double) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK)
            else { continue }

            let name = String(cString: current.pointee.ifa_name)
            guard !name.hasPrefix("lo") else { continue }

            guard let raw = current.pointee.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self)
            received += UInt64(data.pointee.ifi_ibytes)
            sent += UInt64(data.pointee.ifi_obytes)
        }

        let now = Date()
        defer { lastNetwork = (received, sent, now) }

        guard let previous = lastNetwork else { return (0, 0) }
        let elapsed = now.timeIntervalSince(previous.at)
        guard elapsed > 0.05 else { return (0, 0) }

        return (
            Double(received &- previous.received) / elapsed,
            Double(sent &- previous.sent) / elapsed
        )
    }

    // MARK: - Processes

    /// Top processes by CPU.
    ///
    /// Reads `ps` rather than walking `proc_pidinfo`: it needs no entitlement,
    /// costs a few milliseconds, and reports exactly the numbers Activity
    /// Monitor shows, which is what a user will compare against.
    public static func sampleProcesses(limit: Int = 12) -> [ProcessSample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid,pcpu,rss,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
        var results: [ProcessSample] = []

        for line in text.split(separator: "\n").dropFirst() {
            // Command names contain spaces ("Google Chrome"), so only the three
            // leading numeric columns are split off.
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 4,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let rss = Int64(fields[2])
            else { continue }

            let name = fields.dropFirst(3).joined(separator: " ")
            results.append(
                ProcessSample(pid: pid, name: name, cpu: cpu, memory: rss * 1024)
            )
            if results.count >= limit { break }
        }

        return results
    }
}
