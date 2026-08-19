import Foundation

/// A file an uninstall would remove, alongside the app bundle itself.
public struct Leftover: Identifiable, Sendable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let kind: String
    public var size: Int64
    public var isSelected: Bool = true

    public var displayPath: String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

/// Everything an uninstall is about to do, assembled before anything happens.
///
/// Dragging an app to the Trash is what most people do and it leaves the
/// support files, preferences and caches behind. The value here is showing
/// exactly what else exists, with sizes, and letting the user decline any of it.
public struct UninstallPlan: Identifiable, Sendable {
    public var id: String { app.id }
    public let app: InstalledApp
    public var bundleSize: Int64
    public var leftovers: [Leftover]

    public var selectedLeftovers: [Leftover] { leftovers.filter(\.isSelected) }

    public var totalSize: Int64 {
        bundleSize + selectedLeftovers.reduce(0) { $0 + $1.size }
    }

    public var leftoverSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }
}

public enum Uninstaller {

    /// Locations an app is allowed to have written to, keyed by bundle
    /// identifier. Group containers are matched by substring because their
    /// names carry a team prefix (`ABCDE12345.group.com.example`).
    private static func candidatePaths(for app: InstalledApp) -> [(String, String)] {
        let home = NSHomeDirectory()
        let id = app.id

        var entries: [(String, String)] = [
            ("\(home)/Library/Application Support/\(id)", t("应用数据", "App data")),
            ("\(home)/Library/Caches/\(id)", t("缓存", "Cache")),
            ("\(home)/Library/Preferences/\(id).plist", t("偏好设置", "Preferences")),
            ("\(home)/Library/Containers/\(id)", t("沙盒数据", "Sandbox data")),
            ("\(home)/Library/Saved Application State/\(id).savedState", t("窗口状态", "Window state")),
            ("\(home)/Library/HTTPStorages/\(id)", t("网络缓存", "Network cache")),
            ("\(home)/Library/HTTPStorages/\(id).binarycookies", t("Cookie", "Cookies")),
            ("\(home)/Library/WebKit/\(id)", t("网页数据", "Web data")),
            ("\(home)/Library/Application Scripts/\(id)", t("脚本", "Scripts")),
            ("\(home)/Library/LaunchAgents/\(id).plist", t("开机启动项", "Login item")),
            ("\(home)/Library/Cookies/\(id).binarycookies", t("Cookie", "Cookies")),
            ("\(home)/Library/Logs/\(id)", t("日志", "Logs")),
            ("\(home)/Library/Logs/\(app.name)", t("日志", "Logs")),
            ("\(home)/Library/Application Support/\(app.name)", t("应用数据", "App data"))
        ]

        // Group containers and preference files that merely start with the id.
        let fm = FileManager()
        for (root, kind) in [
            ("\(home)/Library/Group Containers", t("共享数据", "Shared data")),
            ("\(home)/Library/Preferences/ByHost", t("偏好设置", "Preferences"))
        ] {
            if let names = try? fm.contentsOfDirectory(atPath: root) {
                for name in names where name.contains(id) {
                    entries.append(("\(root)/\(name)", kind))
                }
            }
        }

        return entries
    }

    /// Builds the plan. Runs off the main actor: this stats a dozen paths and
    /// sizes whatever it finds.
    public static func plan(for app: InstalledApp) async -> UninstallPlan {
        let candidates = candidatePaths(for: app)
        let fm = FileManager()

        var found: [(URL, String)] = []
        var seen = Set<String>()
        for (path, kind) in candidates {
            guard fm.fileExists(atPath: path), !seen.contains(path) else { continue }
            let url = URL(fileURLWithPath: path)
            // The same guard the cleaner uses: an app is not permitted to
            // nominate a protected location as its own leftovers.
            guard SafePath.isRemovable(url) else { continue }
            seen.insert(path)
            found.append((url, kind))
        }

        let bundleSize = await Task.detached(priority: .userInitiated) {
            Sizer.size(of: app.url)
        }.value

        let sizes = await Sizer.sizes(of: found.map(\.0), maxConcurrent: 4)

        var leftovers: [Leftover] = []
        for (index, entry) in found.enumerated() {
            let size = index < sizes.count ? sizes[index] : 0
            leftovers.append(Leftover(url: entry.0, kind: entry.1, size: size))
        }
        leftovers.sort { $0.size > $1.size }

        return UninstallPlan(app: app, bundleSize: bundleSize, leftovers: leftovers)
    }

    /// Executes a plan. The app bundle and its leftovers all go to the Trash,
    /// so an uninstall can be walked back from the Finder like any other.
    @MainActor
    public static func execute(_ plan: UninstallPlan) async -> Removal.Outcome {
        var sizes: [URL: Int64] = [plan.app.url: plan.bundleSize]
        var urls: [URL] = [plan.app.url]

        for leftover in plan.selectedLeftovers {
            urls.append(leftover.url)
            sizes[leftover.url] = leftover.size
        }

        return await Removal.trash(urls, sizes: sizes, policy: .uninstall)
    }
}

/// Several uninstalls reviewed as one operation.
///
/// The single-app sheet exists so nothing is removed unseen; a batch must keep
/// that promise rather than trade it for convenience. So this is still a list
/// of complete plans — every bundle, every leftover, every size — and any app
/// or any individual leftover inside it can still be declined before the one
/// confirmation at the end.
public struct BatchUninstallPlan: Identifiable, Sendable {
    public var id: String
    public var plans: [UninstallPlan]
    /// Apps the user unticked in the sheet, by bundle identifier.
    public var excluded: Set<String> = []

    public init(plans: [UninstallPlan]) {
        self.plans = plans
        self.id = plans.map(\.id).joined(separator: "|")
    }

    public var selectedPlans: [UninstallPlan] {
        plans.filter { !excluded.contains($0.id) }
    }

    public var appCount: Int { selectedPlans.count }

    public var totalSize: Int64 {
        selectedPlans.reduce(0) { $0 + $1.totalSize }
    }

    public var leftoverCount: Int {
        selectedPlans.reduce(0) { $0 + $1.selectedLeftovers.count }
    }

    public func includes(_ id: String) -> Bool {
        !excluded.contains(id)
    }
}

extension Uninstaller {

    /// Builds one plan per app.
    ///
    /// Several at a time, because a dozen `/Applications` walks run strictly
    /// one after another is exactly the pause that makes a batch feel broken.
    /// The window is small on purpose: each plan already spreads its own walk
    /// across a worker pool, so letting every app start at once would just have
    /// the pools fight each other for the disk.
    public static func batchPlan(
        for apps: [InstalledApp],
        onProgress: (@MainActor (Int) -> Void)? = nil
    ) async -> BatchUninstallPlan {
        guard !apps.isEmpty else { return BatchUninstallPlan(plans: []) }

        var plans = await withTaskGroup(of: (Int, UninstallPlan).self) { group in
            let window = min(3, apps.count)
            var next = 0
            while next < window {
                let index = next
                group.addTask { (index, await plan(for: apps[index])) }
                next += 1
            }

            var collected: [(Int, UninstallPlan)] = []
            while let result = await group.next() {
                collected.append(result)
                await onProgress?(collected.count)
                if next < apps.count {
                    let index = next
                    group.addTask { (index, await plan(for: apps[index])) }
                    next += 1
                }
            }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // Biggest first: the reason to review a batch is to see what it frees.
        plans.sort { $0.totalSize > $1.totalSize }
        return BatchUninstallPlan(plans: plans)
    }
}
