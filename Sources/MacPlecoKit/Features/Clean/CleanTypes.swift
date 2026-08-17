import Foundation

public enum CleanCategoryID: String, CaseIterable, Identifiable, Sendable {
    case appCache
    case browser
    case developer
    case ai
    case logs
    case savedState
    case cloud
    case messaging
    case leftovers
    case installers
    case trash

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .appCache: return t("应用缓存", "App caches")
        case .browser: return t("浏览器", "Browsers")
        case .developer: return t("开发工具", "Developer tools")
        case .ai: return t("AI 工具", "AI tools")
        case .logs: return t("日志", "Logs")
        case .savedState: return t("窗口状态", "Saved window state")
        case .cloud: return t("云盘缓存", "Cloud storage")
        case .messaging: return t("聊天软件", "Chat apps")
        case .leftovers: return t("卸载残留", "Leftovers")
        case .installers: return t("安装包", "Installers")
        case .trash: return t("废纸篓", "Trash")
        }
    }

    /// What actually happens after this category is cleaned.
    ///
    /// Every category answers the question a cautious person asks first —
    /// "what will I lose?" — before they are asked to tick anything.
    public var consequence: String {
        switch self {
        case .appCache:
            return t(
                "临时文件，应用下次打开会自动重建，可能稍慢一点。",
                "Temporary files. Apps rebuild them on next launch, which may be slightly slower."
            )
        case .browser:
            return t(
                "只清缓存，登录状态、书签和历史记录都保留。",
                "Cache only. You stay signed in; bookmarks and history are untouched."
            )
        case .developer:
            return t(
                "构建产物和依赖缓存，下次构建会重新下载或编译。",
                "Build output and dependency caches. The next build re-downloads or recompiles."
            )
        case .ai:
            return t(
                "只清临时缓存，对话记录和已下载的本地模型都保留。",
                "Temporary caches only. Conversations and downloaded local models are kept."
            )
        case .logs:
            return t(
                "诊断日志，删掉不影响任何功能。",
                "Diagnostic logs. Removing them affects nothing."
            )
        case .savedState:
            return t(
                "应用重开时窗口位置会回到默认，其他不受影响。",
                "Apps reopen with default window positions. Nothing else changes."
            )
        case .cloud:
            return t(
                "本地同步缓存，需要时会重新下载。",
                "Local sync caches. They re-download when needed."
            )
        case .messaging:
            return t(
                "包含聊天里的图片和视频，清理后旧内容可能无法再下载。",
                "Includes photos and videos from chats. Older content may not be downloadable again."
            )
        case .leftovers:
            return t(
                "已经卸载的应用留下的数据，删掉不影响现有应用。",
                "Data left behind by apps you already removed. Installed apps are unaffected."
            )
        case .installers:
            return t(
                "下载文件夹里的安装包，装完就不需要了。",
                "Installers in your Downloads folder — not needed once the app is installed."
            )
        case .trash:
            return t(
                "废纸篓里的东西会被永久删除，无法恢复。",
                "Items in the Trash are erased permanently and cannot be recovered."
            )
        }
    }

    public var symbol: String {
        switch self {
        case .appCache: return "shippingbox"
        case .browser: return "safari"
        case .developer: return "hammer"
        case .ai: return "brain"
        case .logs: return "doc.text"
        case .savedState: return "macwindow"
        case .cloud: return "cloud"
        case .messaging: return "bubble.left.and.bubble.right"
        case .leftovers: return "archivebox"
        case .installers: return "arrow.down.circle"
        case .trash: return "trash"
        }
    }

    /// Display order — biggest, safest wins first.
    public var rank: Int {
        switch self {
        case .appCache: return 0
        case .developer: return 1
        case .browser: return 2
        case .ai: return 3
        case .logs: return 4
        case .savedState: return 5
        case .cloud: return 6
        case .leftovers: return 7
        case .installers: return 8
        case .messaging: return 9
        case .trash: return 10
        }
    }

    /// Categories whose contents can only be erased outright — there is no
    /// sense in moving the Trash to the Trash.
    public var requiresPermanentDeletion: Bool {
        self == .trash
    }
}

// MARK: - Items

public struct CleanItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let url: URL
    public let title: String
    /// Bundle identifier this item belongs to, when one could be inferred.
    /// Drives the app icon shown beside the row.
    public let bundleID: String?
    public let note: String?
    public let safety: Safety
    public var size: Int64
    public var isSelected: Bool
    /// Name of the running app that owns this path, if any.
    ///
    /// Clearing a cache out from under a live process is the one way a cleaner
    /// can visibly break something, so these are never pre-selected and the
    /// user is told which apps to quit to reclaim the rest.
    public var blockedBy: String?

    public var path: String { url.path }
}

// `Safety` is an enum without associated values, so Hashable and Equatable are
// synthesised for it already — declaring the conformance here would be
// redundant and would not compile.

public struct CleanCategory: Identifiable, Sendable {
    public let id: CleanCategoryID
    public var items: [CleanItem]

    public var title: String { id.title }
    public var consequence: String { id.consequence }
    public var symbol: String { id.symbol }

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    public var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    public var selectedCount: Int { items.filter(\.isSelected).count }

    /// The tri-state a category checkbox shows.
    public enum Selection { case none, partial, all }

    public var selection: Selection {
        let selected = selectedCount
        if selected == 0 { return .none }
        return selected == items.count ? .all : .partial
    }

    /// The strictest safety level present, used to colour the category.
    public var safety: Safety {
        if items.contains(where: { $0.safety == .careful }) { return .careful }
        if items.contains(where: { $0.safety == .review }) { return .review }
        return .safe
    }
}
