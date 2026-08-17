import Foundation
import AppKit
import CoreServices
import Observation

public struct InstalledApp: Identifiable, Sendable, Hashable {
    public let id: String          // bundle identifier
    public let name: String
    public let path: String
    public let version: String
    public let lastUsed: Date?
    public let isSystem: Bool
    public var size: Int64 = 0

    public var url: URL { URL(fileURLWithPath: path) }
}

/// Everything installed on this Mac, indexed by bundle identifier.
///
/// Two features lean on this. The Apps section obviously does, but so does
/// Clean: knowing which bundle identifiers are still installed is what turns
/// an unreadable folder name like `com.figma.Desktop` into "Figma", and what
/// makes it possible to tell leftovers from live application data.
@Observable
@MainActor
public final class AppRegistry {
    public private(set) var apps: [InstalledApp] = []
    public private(set) var byBundleID: [String: InstalledApp] = [:]
    public private(set) var isLoaded = false
    public private(set) var isLoading = false

    public init() {}

    private static var searchRoots: [(path: String, isSystem: Bool)] {
        [
            ("/Applications", false),
            ("/Applications/Utilities", false),
            ("\(NSHomeDirectory())/Applications", false),
            ("/System/Applications", true),
            ("/System/Applications/Utilities", true)
        ]
    }

    public func load(force: Bool = false) async {
        guard force || !isLoaded, !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            isLoaded = true
        }

        let discovered = await Task.detached(priority: .userInitiated) {
            Self.discover()
        }.value

        apps = discovered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        byBundleID = Dictionary(discovered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Fills in bundle sizes, which are far too slow to compute during the
    /// initial listing — the list appears immediately and sizes stream in.
    public func loadSizes(token: ScanToken? = nil) async {
        let urls = apps.map(\.url)
        let sizes = await Sizer.sizes(of: urls, token: token, maxConcurrent: 4)
        guard sizes.count == apps.count else { return }
        for index in apps.indices {
            apps[index].size = sizes[index]
        }
        byBundleID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Human-readable name for a bundle identifier, falling back to a tidied-up
    /// version of the identifier itself when the app is gone.
    public func displayName(forBundleID bundleID: String) -> String {
        if let app = byBundleID[bundleID] { return app.name }
        return AppRegistry.prettifyBundleID(bundleID)
    }

    public func isInstalled(bundleID: String) -> Bool {
        byBundleID[bundleID] != nil
    }

    // MARK: - Discovery

    private nonisolated static func discover() -> [InstalledApp] {
        let fm = FileManager()
        var results: [InstalledApp] = []
        var seenPaths = Set<String>()

        for root in searchRoots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let full = "\(root.path)/\(entry)"
                guard !seenPaths.contains(full) else { continue }
                seenPaths.insert(full)
                if let app = read(bundleAt: full, isSystem: root.isSystem) {
                    results.append(app)
                }
            }
        }
        return results
    }

    private nonisolated static func read(bundleAt path: String, isSystem: Bool) -> InstalledApp? {
        guard let bundle = Bundle(path: path) else { return nil }
        let info = bundle.infoDictionary ?? [:]

        guard let bundleID = bundle.bundleIdentifier, !bundleID.isEmpty else { return nil }

        let displayName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)
            ?? ""

        return InstalledApp(
            id: bundleID,
            name: displayName,
            path: path,
            version: version,
            lastUsed: lastUsedDate(path: path),
            isSystem: isSystem
        )
    }

    /// Spotlight records the last launch date; it is what Finder shows and the
    /// only source that survives a copy. Falls back to the bundle's own
    /// modification date when Spotlight has no entry (indexing disabled, or the
    /// app was never opened).
    private nonisolated static func lastUsedDate(path: String) -> Date? {
        if let item = MDItemCreate(nil, path as CFString),
           let value = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
            return value
        }
        let attributes = try? FileManager().attributesOfItem(atPath: path)
        return attributes?[.modificationDate] as? Date
    }

    /// `com.google.Chrome` -> `Chrome`, `com.tencent.xinWeChat` -> `xinWeChat`.
    /// Crude, but it only runs for identifiers with no installed app behind
    /// them, where any readable label beats the raw string.
    public static func prettifyBundleID(_ bundleID: String) -> String {
        let parts = bundleID.split(separator: ".")
        guard let last = parts.last else { return bundleID }
        if last.count <= 2, parts.count >= 2 {
            return String(parts[parts.count - 2])
        }
        return String(last)
    }
}

// MARK: - Icons

/// Icons are fetched through `NSWorkspace`, which hits the disk. SwiftUI can
/// re-run a row body many times per scroll, so results are memoised here.
@MainActor
public final class IconCache {
    public static let shared = IconCache()
    private var cache: [String: NSImage] = [:]

    private init() {}

    public func icon(forPath path: String) -> NSImage {
        if let hit = cache[path] { return hit }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        cache[path] = image
        return image
    }

    /// Best-effort icon for a bundle identifier that may no longer be
    /// installed; callers fall back to a symbol when this returns nil.
    public func icon(forBundleID bundleID: String, registry: AppRegistry) -> NSImage? {
        guard let app = registry.byBundleID[bundleID] else { return nil }
        return icon(forPath: app.path)
    }
}
