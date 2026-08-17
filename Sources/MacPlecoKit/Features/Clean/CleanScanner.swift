import Foundation
import AppKit

public struct ScanProgress: Sendable {
    public var stage: String
    public var fraction: Double
    public var bytesFound: Int64
}

/// An app holding onto cache that cannot be cleared while it runs.
public struct BlockedApp: Identifiable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    public let bytes: Int64
}

public struct ScanResult: Sendable {
    public var categories: [CleanCategory] = []
    public var blockedApps: [BlockedApp] = []

    public var totalSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    public var blockedBytes: Int64 { blockedApps.reduce(0) { $0 + $1.bytes } }
}

/// A snapshot of main-actor state the scan needs while it runs off the main
/// actor. Copying it up front keeps the walk free of actor hops.
public struct ScanContext: Sendable {
    public var installedBundleIDs: Set<String>
    public var namesByBundleID: [String: String]
    public var runningBundleIDs: [String: String]   // bundle id -> display name

    @MainActor
    public init(registry: AppRegistry) {
        installedBundleIDs = Set(registry.byBundleID.keys)
        namesByBundleID = registry.byBundleID.mapValues(\.name)

        var running: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier else { continue }
            running[id] = app.localizedName ?? AppRegistry.prettifyBundleID(id)
        }
        runningBundleIDs = running
    }
}

public enum CleanScanner {

    // MARK: - Entry point

    public static func scan(
        context: ScanContext,
        token: ScanToken,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> ScanResult {

        onProgress(ScanProgress(stage: t("正在查找可清理的位置…", "Finding what can be cleared…"), fraction: 0.02, bytesFound: 0))

        // 1. Expand every rule into candidate paths.
        var candidates: [Candidate] = []
        var seen = Set<String>()
        let rules = CleanCatalog.rules

        for (index, rule) in rules.enumerated() {
            if token.isCancelled { return ScanResult() }
            for url in expand(rule.pattern) {
                guard accept(url, rule: rule) else { continue }
                let path = url.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                candidates.append(Candidate(url: url, rule: rule))
            }
            onProgress(
                ScanProgress(
                    stage: t("正在查找可清理的位置…", "Finding what can be cleared…"),
                    fraction: 0.02 + 0.18 * (Double(index + 1) / Double(rules.count)),
                    bytesFound: 0
                )
            )
        }

        // 2. Leftovers from apps that are no longer installed.
        for url in leftoverPaths(context: context) {
            let path = url.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            candidates.append(
                Candidate(
                    url: url,
                    rule: CleanRule(
                        category: .leftovers,
                        pattern: path,
                        naming: .bundleIDLeaf,
                        note: t("这个应用已经不在电脑上了", "This app is no longer installed")
                    )
                )
            )
        }

        if token.isCancelled { return ScanResult() }

        // 3. Measure. This dominates the wall clock, so progress is reported
        //    per completed path rather than per rule.
        onProgress(ScanProgress(stage: t("正在计算大小…", "Measuring…"), fraction: 0.22, bytesFound: 0))

        let urls = candidates.map(\.url)
        let total = max(1, urls.count)
        let sizes = await Sizer.sizes(of: urls, token: token, maxConcurrent: 6) { done in
            onProgress(
                ScanProgress(
                    stage: t("正在计算大小…", "Measuring…"),
                    fraction: 0.22 + 0.76 * (Double(done) / Double(total)),
                    bytesFound: 0
                )
            )
        }

        if token.isCancelled { return ScanResult() }
        guard sizes.count == candidates.count else { return ScanResult() }

        // 4. Build items.
        var itemsByCategory: [CleanCategoryID: [CleanItem]] = [:]
        var blocked: [String: Int64] = [:]

        for (index, candidate) in candidates.enumerated() {
            let size = sizes[index]
            // Empty directories are noise: they cost the user attention and
            // return nothing.
            guard size > 0 else { continue }

            let bundleID = inferBundleID(candidate.url, naming: candidate.rule.naming)
            let category = resolveCategory(candidate: candidate, bundleID: bundleID)
            let policy = CleanCatalog.policy(for: category)

            var safety = candidate.rule.safety ?? policy.safety
            var selected = candidate.rule.selectedByDefault ?? policy.selected

            var blockedBy: String?
            if let bundleID, let runningName = context.runningBundleIDs[bundleID] {
                blockedBy = runningName
                blocked[runningName, default: 0] += size
                selected = false
                if safety == .safe { safety = .review }
            }

            let item = CleanItem(
                id: candidate.url.path,
                url: candidate.url,
                title: displayTitle(candidate: candidate, bundleID: bundleID, context: context),
                bundleID: bundleID,
                note: candidate.rule.note,
                safety: safety,
                size: size,
                isSelected: selected,
                blockedBy: blockedBy
            )
            itemsByCategory[category, default: []].append(item)
        }

        // 5. Assemble, biggest item first inside each category.
        var categories: [CleanCategory] = itemsByCategory
            .map { CleanCategory(id: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.id.rank < $1.id.rank }

        // A category whose every item is blocked adds nothing but confusion.
        categories.removeAll { $0.items.isEmpty }

        var result = ScanResult(categories: categories)
        result.blockedApps = blocked
            .map { BlockedApp(name: $0.key, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }

        onProgress(ScanProgress(stage: t("完成", "Done"), fraction: 1, bytesFound: result.totalSize))
        return result
    }

    // MARK: - Candidate

    private struct Candidate {
        let url: URL
        let rule: CleanRule
    }

    // MARK: - Pattern expansion

    /// Expands `~` and `*` components. A `*` matches every entry at that level;
    /// no other wildcard syntax is supported, which keeps the matcher small
    /// enough to reason about.
    static func expand(_ pattern: String) -> [URL] {
        let fm = FileManager()
        let expanded = NSString(string: pattern).expandingTildeInPath
        let components = expanded
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        var current = ["/"]
        for component in components {
            var next: [String] = []
            for base in current {
                if component == "*" {
                    guard let entries = try? fm.contentsOfDirectory(atPath: base) else { continue }
                    for entry in entries {
                        next.append(join(base, entry))
                    }
                } else {
                    let path = join(base, component)
                    if fm.fileExists(atPath: path) { next.append(path) }
                }
            }
            current = next
            if current.isEmpty { break }
        }
        return current.map { URL(fileURLWithPath: $0) }
    }

    private static func join(_ base: String, _ component: String) -> String {
        base == "/" ? "/\(component)" : "\(base)/\(component)"
    }

    // MARK: - Filtering

    private static func accept(_ url: URL, rule: CleanRule) -> Bool {
        guard SafePath.isRemovable(url) else { return false }
        guard !CleanCatalog.isBlocked(url) else { return false }

        if let extensions = rule.fileExtensions {
            guard extensions.contains(url.pathExtension.lowercased()) else { return false }
        }

        if let minAgeDays = rule.minAgeDays {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate else { return false }
            let age = Date().timeIntervalSince(modified) / 86_400
            guard age >= Double(minAgeDays) else { return false }
        }

        return true
    }

    // MARK: - Naming and classification

    static func inferBundleID(_ url: URL, naming: CleanRule.Naming) -> String? {
        switch naming {
        case .fixed, .fileName:
            return nil

        case .bundleIDLeaf:
            var leaf = url.lastPathComponent
            for suffix in [".savedState", ".plist", ".binarycookies"] where leaf.hasSuffix(suffix) {
                leaf = String(leaf.dropLast(suffix.count))
            }
            return looksLikeBundleID(leaf) ? leaf : nil

        case .bundleIDAfter(let marker):
            let components = url.pathComponents
            guard let markerIndex = components.firstIndex(of: marker),
                  markerIndex + 1 < components.count else { return nil }
            let candidate = components[markerIndex + 1]
            return looksLikeBundleID(candidate) ? candidate : nil
        }
    }

    /// Two dots and no spaces is a good enough test in practice; the cost of a
    /// false negative is a slightly uglier label, never a wrong deletion.
    static func looksLikeBundleID(_ value: String) -> Bool {
        guard !value.contains(" "), value.contains(".") else { return false }
        return value.split(separator: ".").count >= 2
    }

    private static func resolveCategory(candidate: Candidate, bundleID: String?) -> CleanCategoryID {
        // The rule's own category wins for anything hand-placed; only the broad
        // sweeps defer to bundle-identifier classification.
        let ruleCategory = candidate.rule.category
        let sweepingCategories: Set<CleanCategoryID> = [.appCache, .logs, .savedState]
        guard sweepingCategories.contains(ruleCategory) else { return ruleCategory }
        return CleanCatalog.category(forBundleID: bundleID) ?? ruleCategory
    }

    private static func displayTitle(
        candidate: Candidate,
        bundleID: String?,
        context: ScanContext
    ) -> String {
        switch candidate.rule.naming {
        case .fixed(let label):
            return label
        case .fileName:
            return candidate.url.lastPathComponent
        case .bundleIDLeaf, .bundleIDAfter:
            guard let bundleID else { return candidate.url.lastPathComponent }
            if let name = context.namesByBundleID[bundleID] { return name }
            return AppRegistry.prettifyBundleID(bundleID)
        }
    }

    // MARK: - Leftovers

    /// Data belonging to bundle identifiers with no installed app behind them.
    ///
    /// Restricted to the directories where a folder genuinely implies an app —
    /// cache folders are excluded, because plenty of them belong to frameworks
    /// and command-line tools that were never in `/Applications` and calling
    /// those "leftovers" would be alarming and wrong.
    private static func leftoverPaths(context: ScanContext) -> [URL] {
        let home = NSHomeDirectory()
        let roots = [
            "\(home)/Library/Application Support",
            "\(home)/Library/Containers",
            "\(home)/Library/Application Scripts"
        ]

        var results: [URL] = []
        let fm = FileManager()

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                guard looksLikeBundleID(entry) else { continue }
                guard !entry.hasPrefix("com.apple.") else { continue }
                guard !context.installedBundleIDs.contains(entry) else { continue }

                let url = URL(fileURLWithPath: join(root, entry))
                guard SafePath.isRemovable(url), !CleanCatalog.isBlocked(url) else { continue }

                // Skip anything touched recently: an app mid-install, or a
                // helper whose parent app lives somewhere unusual.
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                if let modified = values?.contentModificationDate,
                   Date().timeIntervalSince(modified) < 30 * 86_400 {
                    continue
                }
                results.append(url)
            }
        }
        return results
    }
}
