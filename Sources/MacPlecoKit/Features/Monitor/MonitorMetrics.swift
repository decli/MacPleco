import Foundation
import Darwin
import IOKit
import AppKit

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
    /// What to call it in the table: the innermost `.app` bundle name when the
    /// executable lives in one, otherwise the executable's own name.
    public let name: String
    /// Absolute path to the executable. Empty only when `ps` could not report
    /// one, which happens for a handful of kernel-side entries.
    public let path: String
    public let cpu: Double
    public let memory: Int64
    public let uid: uid_t
    public let started: Date?

    /// Owned by the system rather than by the person using the Mac.
    ///
    /// Two signals, because either alone is wrong: accounts below uid 500 are
    /// reserved by macOS for daemons, and anything running out of the read-only
    /// system volume belongs to the OS even when it runs as you — the Finder
    /// and the Dock are yours to use but not yours to manage.
    public var isSystem: Bool {
        if uid < 500 { return true }
        return Self.systemPrefixes.contains { path.hasPrefix($0) }
    }

    private static let systemPrefixes = [
        "/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/"
    ]

    /// What "Show in Finder" should select: the app bundle if there is one, so
    /// the user lands on Chrome rather than on a binary buried six folders
    /// deep inside it.
    public var revealURL: URL? {
        guard !path.isEmpty else { return nil }
        if let bundle = Self.enclosingBundle(of: path) {
            return URL(fileURLWithPath: bundle)
        }
        return URL(fileURLWithPath: path)
    }

    public init(
        pid: Int32,
        name: String,
        path: String = "",
        cpu: Double,
        memory: Int64,
        uid: uid_t = 0,
        started: Date? = nil
    ) {
        self.pid = pid
        self.name = name
        self.path = path
        self.cpu = cpu
        self.memory = memory
        self.uid = uid
        self.started = started
    }

    /// The innermost `.app` on the path. Innermost rather than outermost so a
    /// browser's renderer helper is named after the helper — which is the row
    /// you would want to identify — instead of collapsing into the browser.
    static func enclosingBundle(of path: String) -> String? {
        guard let range = path.range(of: ".app/", options: .backwards) else {
            return path.hasSuffix(".app") ? path : nil
        }
        return String(path[path.startIndex..<range.lowerBound]) + ".app"
    }

    static func displayName(forPath path: String) -> String {
        guard !path.isEmpty else { return "?" }
        if let bundle = enclosingBundle(of: path) {
            return (bundle as NSString).lastPathComponent
                .replacingOccurrences(of: ".app", with: "")
        }
        return (path as NSString).lastPathComponent
    }
}

/// Whole-device GPU load.
///
/// Per-*process* GPU is a different question and macOS has no public answer to
/// it: there are no `IOAccelCommandQueue` entries carrying a pid on Apple
/// silicon, and the only tool that can attribute GPU time to a process
/// (`powermetrics`) needs root. The device totals below, however, are plain
/// IORegistry properties any app may read — so the page reports those instead
/// of a column that could only ever be empty.
public struct GPUSample: Sendable, Equatable {
    public var device: Double?
    public var renderer: Double?
    public var tiler: Double?
    public var inUseMemory: Int64?

    public var isAvailable: Bool { device != nil }
}

/// Ending a process, with the same reversibility instinct as the rest of the
/// app: ask politely first, and only insist when told to.
public enum ProcessControl {

    public enum Outcome: Sendable {
        case asked
        case forced
        /// The process belongs to another user — almost always root. Ending it
        /// would need administrator rights, which this app does not take.
        case denied
        case gone

        public var message: String {
            switch self {
            case .asked:
                return t("已请求退出", "Asked it to quit")
            case .forced:
                return t("已强制结束", "Force quit")
            case .denied:
                return t(
                    "这个进程属于系统账户，需要管理员权限才能结束。",
                    "This process belongs to a system account and needs administrator rights to end."
                )
            case .gone:
                return t("这个进程已经不在了", "That process is already gone")
            }
        }

        public var succeeded: Bool {
            self == .asked || self == .forced
        }
    }

    /// GUI apps are asked through `NSRunningApplication`, which gives them the
    /// chance to save open documents. Everything else gets a signal.
    @MainActor
    public static func end(pid: Int32, force: Bool) -> Outcome {
        if let running = NSRunningApplication(processIdentifier: pid) {
            let ok = force ? running.forceTerminate() : running.terminate()
            if ok { return force ? .forced : .asked }
        }

        let result = kill(pid, force ? SIGKILL : SIGTERM)
        if result == 0 { return force ? .forced : .asked }
        switch errno {
        case EPERM: return .denied
        case ESRCH: return .gone
        default: return .denied
        }
    }
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

    /// All visible processes with CPU and resident-memory counters.
    ///
    /// Reads `ps` rather than walking `proc_pidinfo`: it needs no entitlement,
    /// costs a few milliseconds, and reports exactly the numbers Activity
    /// Monitor shows, which is what a user will compare against.
    public static func sampleProcesses(limit: Int? = nil) -> [ProcessSample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // `-ww` stops long executable paths being truncated to the terminal
        // width, and dropping `-c` is what makes `comm` report the full path
        // rather than just a name — that path is what powers "Show in Finder",
        // the system/app split and the icon lookup.
        //
        // `etime` is chosen over `lstart` deliberately: it is a single
        // whitespace-free token, so the columns stay unambiguously splittable
        // even though command paths contain spaces.
        process.arguments = ["-Awwxo", "pid=,pcpu=,rss=,uid=,etime=,comm="]

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
        let now = Date()
        var results: [ProcessSample] = []

        for line in text.split(separator: "\n") {
            // Only the five leading numeric columns are split off; whatever
            // follows is the path, spaces and all.
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 6,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let rss = Int64(fields[2]),
                  let uid = UInt32(fields[3])
            else { continue }

            let path = fields.dropFirst(5).joined(separator: " ")
            let started = elapsedSeconds(fields[4]).map { now.addingTimeInterval(-$0) }

            results.append(
                ProcessSample(
                    pid: pid,
                    name: ProcessSample.displayName(forPath: path),
                    path: path,
                    cpu: cpu,
                    memory: rss * 1024,
                    uid: uid_t(uid),
                    started: started
                )
            )
            if let limit, results.count >= limit { break }
        }

        return results
    }

    /// Parses `ps` elapsed time — `[[dd-]hh:]mm:ss` — into seconds.
    private static func elapsedSeconds(_ text: Substring) -> TimeInterval? {
        var days: Double = 0
        var remainder = text

        if let dash = remainder.firstIndex(of: "-") {
            days = Double(remainder[remainder.startIndex..<dash]) ?? 0
            remainder = remainder[remainder.index(after: dash)...]
        }

        let parts = remainder.split(separator: ":").map { Double($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }

        // Each column to the left is worth sixty of the one to its right.
        var seconds: Double = 0
        for part in parts { seconds = seconds * 60 + (part ?? 0) }
        return days * 86_400 + seconds
    }

    // MARK: - GPU

    /// Whole-device GPU load, read straight from the IORegistry.
    ///
    /// Every accelerator publishes a `PerformanceStatistics` dictionary; on a
    /// machine with more than one GPU the busiest is reported, which is what
    /// "how hard is the graphics hardware working" means to a user.
    public static func sampleGPU() -> GPUSample {
        var sample = GPUSample()

        guard let matching = IOServiceMatching("IOAccelerator") else { return sample }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else { return sample }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }

            guard let property = IORegistryEntryCreateCFProperty(
                entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
            ), let statistics = property.takeRetainedValue() as? [String: Any] else { continue }

            func share(_ key: String) -> Double? {
                guard let raw = statistics[key] as? NSNumber else { return nil }
                return min(1, max(0, raw.doubleValue / 100))
            }

            if let device = share("Device Utilization %") {
                sample.device = max(sample.device ?? 0, device)
            }
            if let renderer = share("Renderer Utilization %") {
                sample.renderer = max(sample.renderer ?? 0, renderer)
            }
            if let tiler = share("Tiler Utilization %") {
                sample.tiler = max(sample.tiler ?? 0, tiler)
            }
            if let memory = statistics["In use system memory"] as? NSNumber {
                sample.inUseMemory = max(sample.inUseMemory ?? 0, memory.int64Value)
            }
        }

        return sample
    }
}
