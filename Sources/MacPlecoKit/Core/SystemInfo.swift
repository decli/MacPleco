import Foundation
import Darwin

/// Cheap, static facts about this Mac. Everything here is a sysctl or a
/// `ProcessInfo` lookup, so it is safe to read on the main actor.
public enum SystemInfo {

    public static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    public static func sysctlInt(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    /// Marketing-ish chip name, e.g. "Apple M5 Max".
    public static var chip: String {
        sysctlString("machdep.cpu.brand_string") ?? t("未知芯片", "Unknown chip")
    }

    public static var model: String {
        sysctlString("hw.model") ?? "Mac"
    }

    public static var physicalMemory: Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    public static var performanceCoreCount: Int {
        Int(sysctlInt("hw.perflevel0.logicalcpu") ?? 0)
    }

    public static var coreCount: Int {
        ProcessInfo.processInfo.processorCount
    }

    public static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    public static var bootTime: Date? {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(boot.tv_sec))
    }

    public static var uptime: TimeInterval {
        guard let bootTime else { return 0 }
        return Date().timeIntervalSince(bootTime)
    }

    /// macOS's own view of thermal headroom.
    ///
    /// Fan speeds and die temperatures need either root or the private SMC
    /// interface. Rather than ship a fragile reimplementation of either — or
    /// invent a plausible-looking number — the app reports the public signal
    /// and says nothing it cannot stand behind.
    public static var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    public static var thermalDescription: String {
        switch thermalState {
        case .nominal: return t("正常", "Normal")
        case .fair: return t("温热", "Warm")
        case .serious: return t("偏热", "Hot")
        case .critical: return t("过热", "Overheating")
        @unknown default: return t("未知", "Unknown")
        }
    }
}
