import Foundation

/// One pattern the scanner expands into removable paths.
public struct CleanRule: Sendable {

    /// How to turn a matched path into something a person can read.
    public enum Naming: Sendable {
        /// The final path component is a bundle identifier.
        case bundleIDLeaf
        /// The component immediately after the named one is a bundle identifier
        /// (`~/Library/Containers/<id>/Data/...`).
        case bundleIDAfter(String)
        /// Use the file or folder name as-is.
        case fileName
        /// A hand-written label, for paths whose name means nothing.
        case fixed(String)
    }

    public var category: CleanCategoryID
    /// `~` is expanded; a `*` component matches every entry at that level.
    public var pattern: String
    public var naming: Naming = .bundleIDLeaf
    /// Overrides the category default when a specific path deserves more care.
    public var safety: Safety?
    public var selectedByDefault: Bool?
    public var note: String?
    /// Skip entries modified more recently than this.
    public var minAgeDays: Int?
    /// Restrict matches to files carrying one of these extensions.
    public var fileExtensions: Set<String>?
}

/// The rules, plus the tables that decide which category a path really belongs
/// to and how careful the app should be with it.
public enum CleanCatalog {

    // MARK: - Bundle identifier classification
    //
    // Generic patterns such as `~/Library/Caches/*` sweep up everything,
    // including apps whose caches deserve very different treatment. Rather than
    // hand-writing mutually exclusive globs — which drift and overlap — the
    // scanner harvests broadly and then reclassifies by bundle identifier here.

    private static let messagingIDs = [
        "com.tencent.xinweChat", "com.tencent.xinWeChat", "com.tencent.WeWorkMac",
        "com.tencent.qq", "com.tencent.QQMusic", "com.tencent.meeting",
        "com.electron.wechat", "com.slack", "com.tinyspeck.slackmacgap",
        "com.hnc.Discord", "com.discordapp",
        "ru.keepcoder.Telegram", "org.telegram", "com.telegram",
        "net.whatsapp.WhatsApp", "WhatsApp",
        "com.microsoft.teams", "com.skype",
        "com.apple.MobileSMS", "com.apple.iChat",
        "com.alibaba.DingTalkMac", "com.taobao.DingTalk",
        "com.bytedance.lark", "com.larksuite",
        "com.readdle.smartemail", "com.netease.mail"
    ]

    private static let browserIDs = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.apple.Safari",
        "org.mozilla.firefox", "org.mozilla.nightly",
        "com.microsoft.edgemac", "company.thebrowser.Browser",
        "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS", "org.chromium.Chromium",
        "com.UCMobile.MacUC", "com.qihoo.browser", "com.tencent.QQBrowser"
    ]

    private static let aiIDs = [
        "com.openai.chat", "com.anthropic.claudefordesktop", "com.anthropic",
        "com.todesktop.230313mzl4w4u92", "com.exafunction.windsurf",
        "dev.warp.Warp-Stable", "com.github.GitHubClient",
        "ai.perplexity", "com.raycast.macos.ai", "com.lmstudio",
        "com.jan.ai", "ai.elementlabs", "com.ollama"
    ]

    private static let cloudIDs = [
        "com.dropbox", "com.getdropbox", "com.microsoft.OneDrive",
        "com.google.GoogleDrive", "com.google.drivefs",
        "com.baidu.BaiduNetdisk", "com.baidu.netdisk",
        "com.pcloud", "com.box.desktop", "com.synology", "com.owncloud",
        "com.nextcloud", "com.aliyun.drive", "com.115"
    ]

    private static let developerIDs = [
        "com.apple.dt.Xcode", "com.apple.dt", "com.docker.docker",
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders",
        "com.jetbrains", "com.sublimetext", "com.panic.Nova",
        "com.postmanlabs", "org.swift", "com.googlecode.iterm2",
        "co.zeit.hyper", "com.figma.Desktop", "org.virtualbox",
        "com.utmapp.UTM", "com.parallels"
    ]

    /// Which category a bundle identifier really belongs to, if the tables have
    /// an opinion. Matching is by prefix so app variants and channels
    /// (`com.google.Chrome.beta`) land alongside their stable build.
    public static func category(forBundleID bundleID: String?) -> CleanCategoryID? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        let lowered = bundleID.lowercased()

        func matches(_ table: [String]) -> Bool {
            table.contains { lowered.hasPrefix($0.lowercased()) }
        }

        if matches(messagingIDs) { return .messaging }
        if matches(browserIDs) { return .browser }
        if matches(aiIDs) { return .ai }
        if matches(cloudIDs) { return .cloud }
        if matches(developerIDs) { return .developer }
        return nil
    }

    /// Default handling per category. Anything holding content a user may not
    /// be able to get back again is never pre-selected.
    public static func policy(for category: CleanCategoryID) -> (safety: Safety, selected: Bool) {
        switch category {
        case .appCache, .logs, .savedState, .cloud, .ai:
            return (.safe, true)
        case .developer:
            return (.safe, true)
        case .browser:
            return (.safe, true)
        case .leftovers, .installers:
            return (.review, false)
        case .messaging:
            return (.careful, false)
        case .trash:
            return (.review, false)
        }
    }

    // MARK: - Paths that must never be offered
    //
    // These sit inside allowed roots but hold state that is expensive or
    // impossible to rebuild. `SafePath` refuses them too; listing them here
    // keeps them out of the UI so a user is never tempted.

    private static let neverOffer: [String] = [
        ".ollama/models",
        "models",
        "Library/Application Support/Ollama/models",
        // Model downloads that live under `~/.cache`. The weight heuristic
        // below only fires on the matched path, and these are matched at their
        // top level, so name them.
        ".cache/huggingface",
        ".cache/torch",
        ".cache/lm-studio",
        "Library/Caches/com.apple.iTunes",
        "Library/Caches/CloudKit",
        "Library/Caches/com.apple.homed",
        "Library/Caches/com.apple.Safari/SafariTabSnapshots",
        "Library/Containers/com.apple.mail",
        "Library/Containers/com.apple.Notes",
        "Library/Containers/com.apple.Photos",
        "Library/Containers/com.apple.reminders",
        "Library/Containers/com.apple.stocks",
        "Library/Application Support/MobileSync",
        "Library/Application Support/minecraft",
        "Library/Developer/CoreSimulator/Devices",
        ".docker/machine",
        ".ssh",
        ".gnupg",
        ".aws",
        ".kube"
    ]

    /// Directories that mix a throwaway cache with state the tool cannot
    /// rebuild. Removal takes the whole matched directory, so the directory
    /// itself is never offered — only the rules naming its cache reach inside.
    private static let neverOfferWhole: [String] = [
        ".cache/pypoetry"   // holds `virtualenvs`, which are working environments
    ]

    public static func isBlocked(_ url: URL) -> Bool {
        let home = NSHomeDirectory()
        let path = url.standardizedFileURL.path
        for suffix in neverOffer {
            let full = "\(home)/\(suffix)"
            if path == full || path.hasPrefix(full + "/") { return true }
        }
        for suffix in neverOfferWhole where path == "\(home)/\(suffix)" { return true }
        // Anything that looks like a downloaded model weight stays put; these
        // are enormous, slow to fetch and frequently sit in cache directories.
        let lowered = path.lowercased()
        for marker in ["/models/", ".gguf", ".safetensors", ".mlmodelc", "/blobs/sha256"] {
            if lowered.contains(marker) { return true }
        }
        return false
    }

    // MARK: - Rules

    public static var rules: [CleanRule] {
        var all: [CleanRule] = []

        // --- Application caches -------------------------------------------
        all += [
            CleanRule(category: .appCache, pattern: "~/Library/Caches/*"),
            CleanRule(
                category: .appCache,
                pattern: "~/Library/Containers/*/Data/Library/Caches",
                naming: .bundleIDAfter("Containers")
            ),
            CleanRule(
                category: .appCache,
                pattern: "~/Library/HTTPStorages/*",
                note: t("网络请求缓存", "Network request cache")
            ),
            CleanRule(category: .appCache, pattern: "~/Library/WebKit/*"),
            CleanRule(
                category: .appCache,
                pattern: "~/Library/Group Containers/*/Library/Caches",
                naming: .bundleIDAfter("Group Containers")
            )
        ]

        // --- Logs ----------------------------------------------------------
        all += [
            CleanRule(category: .logs, pattern: "~/Library/Logs/*", naming: .fileName),
            CleanRule(
                category: .logs,
                pattern: "~/Library/Application Support/CrashReporter/*",
                naming: .fileName
            ),
            CleanRule(
                category: .logs,
                pattern: "~/Library/Containers/*/Data/Library/Logs",
                naming: .bundleIDAfter("Containers")
            )
        ]

        // --- Saved window state ---------------------------------------------
        all += [
            CleanRule(
                category: .savedState,
                pattern: "~/Library/Saved Application State/*",
                minAgeDays: 14
            )
        ]

        // --- Developer tooling ----------------------------------------------
        all += [
            CleanRule(
                category: .developer,
                pattern: "~/Library/Developer/Xcode/DerivedData/*",
                naming: .fileName,
                note: t("Xcode 构建产物", "Xcode build output")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Developer/Xcode/iOS DeviceSupport/*",
                naming: .fileName,
                note: t("连接设备后会重新生成", "Regenerated when you reconnect the device")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Developer/Xcode/watchOS DeviceSupport/*",
                naming: .fileName
            ),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Developer/CoreSimulator/Caches/*",
                naming: .fileName
            ),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Developer/Xcode/Archives/*",
                naming: .fileName,
                safety: .careful,
                selectedByDefault: false,
                note: t("已归档的发布构建，删掉无法重新签名上传", "Archived release builds — cannot be re-signed once gone")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Caches/org.swift.swiftpm",
                naming: .fixed("Swift Package Manager")
            ),
            CleanRule(category: .developer, pattern: "~/Library/Caches/Homebrew/*", naming: .fileName),
            CleanRule(category: .developer, pattern: "~/Library/Caches/go-build", naming: .fixed("Go build cache")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/pip", naming: .fixed("pip")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/uv", naming: .fixed("uv")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/deno", naming: .fixed("Deno")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/bun", naming: .fixed("Bun")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/typescript", naming: .fixed("TypeScript")),
            CleanRule(category: .developer, pattern: "~/Library/Caches/CocoaPods", naming: .fixed("CocoaPods")),
            CleanRule(
                category: .developer,
                pattern: "~/Library/Caches/ms-playwright",
                naming: .fixed("Playwright browsers"),
                safety: .review,
                selectedByDefault: false,
                note: t("重新下载浏览器需要较长时间", "Re-downloading the browsers takes a while")
            ),
            CleanRule(category: .developer, pattern: "~/.npm/_cacache", naming: .fixed("npm")),
            CleanRule(category: .developer, pattern: "~/.yarn/cache", naming: .fixed("Yarn")),
            CleanRule(category: .developer, pattern: "~/.pnpm-store", naming: .fixed("pnpm")),
            CleanRule(category: .developer, pattern: "~/.cargo/registry/cache", naming: .fixed("Cargo registry")),
            CleanRule(category: .developer, pattern: "~/.gradle/caches", naming: .fixed("Gradle")),
            CleanRule(
                category: .developer,
                pattern: "~/.m2/repository",
                naming: .fixed("Maven"),
                safety: .review,
                selectedByDefault: false,
                note: t("重新下载依赖较慢", "Dependencies are slow to re-download")
            ),
            // `~/.cache` is a shared drawer rather than one tool's cache: some
            // entries are throwaway, others are the only copy of something.
            // Name the ones that really are caches, and leave the sweep that
            // catches the rest as something to look at rather than tick.
            CleanRule(category: .developer, pattern: "~/.cache/pip", naming: .fixed("pip")),
            CleanRule(category: .developer, pattern: "~/.cache/uv", naming: .fixed("uv")),
            CleanRule(category: .developer, pattern: "~/.cache/go-build", naming: .fixed("Go build cache")),
            CleanRule(category: .developer, pattern: "~/.cache/pre-commit", naming: .fixed("pre-commit")),
            CleanRule(
                category: .developer,
                pattern: "~/.cache/pypoetry/artifacts",
                naming: .fixed("Poetry artifacts")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/.cache/pypoetry/cache",
                naming: .fixed("Poetry cache")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/.cache/ms-playwright",
                naming: .fixed("Playwright browsers"),
                safety: .review,
                selectedByDefault: false,
                note: t("重新下载浏览器需要较长时间", "Re-downloading the browsers takes a while")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/.cache/puppeteer",
                naming: .fixed("Puppeteer browsers"),
                safety: .review,
                selectedByDefault: false,
                note: t("重新下载浏览器需要较长时间", "Re-downloading the browsers takes a while")
            ),
            CleanRule(
                category: .developer,
                pattern: "~/.cache/*",
                naming: .fileName,
                safety: .review,
                selectedByDefault: false,
                note: t("里面可能是工具要用的状态，不只是缓存", "May hold state a tool needs, not just cache")
            ),
            CleanRule(category: .developer, pattern: "~/.nvm/.cache", naming: .fixed("nvm")),
            CleanRule(category: .developer, pattern: "~/.electron", naming: .fixed("Electron")),
            CleanRule(category: .developer, pattern: "~/.electron-gyp", naming: .fixed("electron-gyp"))
        ]

        // --- Browsers --------------------------------------------------------
        // Chromium-family browsers keep several distinct caches per profile.
        for browser in [
            ("Google/Chrome", "Chrome"),
            ("Microsoft Edge", "Edge"),
            ("BraveSoftware/Brave-Browser", "Brave"),
            ("Vivaldi", "Vivaldi"),
            ("Chromium", "Chromium")
        ] {
            for cache in ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache"] {
                all.append(
                    CleanRule(
                        category: .browser,
                        pattern: "~/Library/Application Support/\(browser.0)/*/\(cache)",
                        naming: .fixed(browser.1)
                    )
                )
            }
            all.append(
                CleanRule(
                    category: .browser,
                    pattern: "~/Library/Application Support/\(browser.0)/*/Service Worker/CacheStorage",
                    naming: .fixed(browser.1),
                    safety: .review,
                    selectedByDefault: false,
                    note: t("清理后部分网页应用需要重新登录", "Some web apps will ask you to sign in again")
                )
            )
            all.append(
                CleanRule(
                    category: .browser,
                    pattern: "~/Library/Caches/\(browser.0)/*",
                    naming: .fileName
                )
            )
        }
        all.append(
            CleanRule(
                category: .browser,
                pattern: "~/Library/Caches/Firefox/Profiles/*",
                naming: .fixed("Firefox")
            )
        )

        // --- Cloud storage ---------------------------------------------------
        all += [
            CleanRule(
                category: .cloud,
                pattern: "~/Library/Application Support/Google/DriveFS/*/content_cache",
                naming: .fixed("Google Drive"),
                safety: .review,
                selectedByDefault: false,
                note: t("离线可用的文件需要重新下载", "Files kept offline will re-download")
            ),
            CleanRule(
                category: .cloud,
                pattern: "~/Library/Application Support/OneDrive/logs",
                naming: .fixed("OneDrive")
            )
        ]

        // --- Installers ------------------------------------------------------
        all += [
            CleanRule(
                category: .installers,
                pattern: "~/Downloads/*",
                naming: .fileName,
                minAgeDays: 30,
                fileExtensions: ["dmg", "pkg", "mpkg"]
            )
        ]

        // --- Trash -----------------------------------------------------------
        all += [
            CleanRule(category: .trash, pattern: "~/.Trash/*", naming: .fileName)
        ]

        // The scanner keeps the first rule to reach a path, so a hand-written
        // rule has to be seen before the sweep it sits inside — otherwise its
        // category, label and safety never apply. Whenever one pattern covers
        // everything another can match, it is the one with more `*`
        // components, so ordering by wildcard count puts the specific rule
        // first no matter which section it was written in. The sort is made
        // stable by hand: Swift's is not, and each section's own order matters.
        return all.enumerated()
            .sorted { lhs, rhs in
                let left = wildcardCount(lhs.element.pattern)
                let right = wildcardCount(rhs.element.pattern)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    private static func wildcardCount(_ pattern: String) -> Int {
        pattern.split(separator: "/").count { $0 == "*" }
    }
}
