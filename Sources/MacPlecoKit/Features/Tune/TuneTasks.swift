import Foundation

/// What a maintenance task actually does.
///
/// Every command is a fixed executable path with a fixed argument list. No
/// user input reaches any of them, and there is no shell in the chain, so
/// there is nothing here that can be turned into a different command.
enum TuneAction: Sendable {
    case command(path: String, arguments: [String])
    case setDefault(domain: String, key: String, enabled: Bool)
    case removeMatching(pattern: String, olderThanDays: Int?)
}

public struct TuneTask: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    /// The visible consequence, if there is one. Restarting the Dock makes the
    /// screen flicker; saying so beforehand is the difference between a fix
    /// and a fright.
    public let warning: String?
    public let symbol: String
    let action: TuneAction
}

public struct TuneResult: Identifiable, Sendable {
    public var id: String { taskID }
    public let taskID: String
    public let succeeded: Bool
    public let message: String
}

public enum TuneCatalog {

    public static var tasks: [TuneTask] {
        [
            TuneTask(
                id: "launch-services",
                title: t("修复「打开方式」菜单", "Repair the Open With menu"),
                detail: t(
                    "重建应用注册表，解决右键菜单里重复或失效的条目。",
                    "Rebuilds the app registry, clearing duplicate or dead entries from the right-click menu."
                ),
                warning: nil,
                symbol: "list.bullet.rectangle",
                action: .command(
                    path: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                    arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
                )
            ),
            TuneTask(
                id: "quicklook",
                title: t("刷新预览缩略图", "Refresh preview thumbnails"),
                detail: t(
                    "清空快速查看的缩略图缓存，解决访达里预览图错乱或空白。",
                    "Clears the Quick Look thumbnail cache, fixing blank or wrong previews in the Finder."
                ),
                warning: nil,
                symbol: "eye",
                action: .command(path: "/usr/bin/qlmanage", arguments: ["-r", "cache"])
            ),
            TuneTask(
                id: "font-cache",
                title: t("清理字体缓存", "Clear font caches"),
                detail: t(
                    "重建字体数据库，解决字体显示为方块或应用里字体列表异常。",
                    "Rebuilds the font database, fixing tofu boxes and broken font menus."
                ),
                warning: t("建议之后重启一次相关应用。", "Reopen affected apps afterwards."),
                symbol: "textformat",
                action: .command(path: "/usr/bin/atsutil", arguments: ["databases", "-removeUser"])
            ),
            TuneTask(
                id: "dns",
                title: t("刷新 DNS 缓存", "Flush the DNS cache"),
                detail: t(
                    "清空域名解析缓存，解决网站换了服务器后打不开的问题。",
                    "Clears cached domain lookups, fixing sites that stopped loading after moving servers."
                ),
                warning: nil,
                symbol: "network",
                action: .command(path: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
            ),
            TuneTask(
                id: "icon-cache",
                title: t("重建图标缓存", "Rebuild the icon cache"),
                detail: t(
                    "删除图标缓存并重启程序坞，解决应用图标显示成白纸的问题。",
                    "Clears cached icons and restarts the Dock, fixing apps showing a blank page icon."
                ),
                warning: t("程序坞会闪一下并自动回来。", "The Dock will blink and come straight back."),
                symbol: "app.badge",
                action: .removeMatching(pattern: "~/Library/Caches/com.apple.iconservices.store", olderThanDays: nil)
            ),
            TuneTask(
                id: "ds-store",
                title: t("不在网络磁盘留下 .DS_Store", "Stop writing .DS_Store on network drives"),
                detail: t(
                    "让访达停止在共享盘和 U 盘里生成隐藏文件，同事就不会再看到它们。",
                    "Stops the Finder littering shared and USB drives with hidden files your colleagues can see."
                ),
                warning: nil,
                symbol: "externaldrive.badge.xmark",
                action: .setDefault(
                    domain: "com.apple.desktopservices",
                    key: "DSDontWriteNetworkStores",
                    enabled: true
                )
            ),
            TuneTask(
                id: "saved-state",
                title: t("清理陈旧的窗口状态", "Clear stale window state"),
                detail: t(
                    "删除一个月以上没用过的窗口位置记录，解决应用打开时窗口跑到屏幕外。",
                    "Removes month-old window position records, fixing apps that reopen off-screen."
                ),
                warning: nil,
                symbol: "macwindow",
                action: .removeMatching(pattern: "~/Library/Saved Application State/*", olderThanDays: 30)
            ),
            TuneTask(
                id: "restart-finder",
                title: t("重启访达", "Restart the Finder"),
                detail: t(
                    "解决访达卡住、侧边栏不刷新、外接硬盘不显示等临时故障。",
                    "Fixes a stuck Finder, a stale sidebar, or drives that refuse to appear."
                ),
                warning: t("所有访达窗口会关闭。", "All Finder windows will close."),
                symbol: "arrow.clockwise",
                action: .command(path: "/usr/bin/killall", arguments: ["Finder"])
            )
        ]
    }
}

enum TuneRunner {

    /// Runs one task. Returns a message worth showing rather than raw output.
    static func run(_ task: TuneTask) async -> TuneResult {
        await Task.detached(priority: .userInitiated) {
            switch task.action {
            case .command(let path, let arguments):
                return execute(task: task, path: path, arguments: arguments)

            case .setDefault(let domain, let key, let enabled):
                return execute(
                    task: task,
                    path: "/usr/bin/defaults",
                    arguments: ["write", domain, key, "-bool", enabled ? "true" : "false"]
                )

            case .removeMatching(let pattern, let olderThanDays):
                return removeMatching(task: task, pattern: pattern, olderThanDays: olderThanDays)
            }
        }.value
    }

    private static func execute(task: TuneTask, path: String, arguments: [String]) -> TuneResult {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return TuneResult(
                taskID: task.id,
                succeeded: false,
                message: t("这个系统上找不到对应的工具。", "That tool isn't present on this system.")
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return TuneResult(
                taskID: task.id,
                succeeded: false,
                message: t("无法启动：\(error.localizedDescription)", "Couldn't start: \(error.localizedDescription)")
            )
        }

        // Drained before waiting so a chatty command cannot fill the pipe
        // buffer and deadlock against its own exit.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return TuneResult(taskID: task.id, succeeded: true, message: t("完成", "Done"))
        }

        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = output.isEmpty
            ? t("退出码 \(process.terminationStatus)", "Exit code \(process.terminationStatus)")
            : String(output.prefix(160))
        return TuneResult(taskID: task.id, succeeded: false, message: detail)
    }

    private static func removeMatching(
        task: TuneTask,
        pattern: String,
        olderThanDays: Int?
    ) -> TuneResult {
        let matches = CleanScanner.expand(pattern)
        var removed = 0
        var freed: Int64 = 0
        let fm = FileManager()

        for url in matches {
            guard SafePath.isRemovable(url) else { continue }
            if let olderThanDays {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                guard let modified = values?.contentModificationDate,
                      Date().timeIntervalSince(modified) >= Double(olderThanDays) * 86_400
                else { continue }
            }
            let size = Sizer.size(of: url)
            do {
                try fm.removeItem(at: url)
                removed += 1
                freed += size
            } catch {
                continue
            }
        }

        // The icon cache only takes effect once the Dock reloads it.
        if task.id == "icon-cache" {
            let dock = Process()
            dock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            dock.arguments = ["Dock"]
            try? dock.run()
            dock.waitUntilExit()
        }

        if removed == 0 {
            return TuneResult(
                taskID: task.id,
                succeeded: true,
                message: t("没有需要清理的内容", "Nothing needed clearing")
            )
        }
        return TuneResult(
            taskID: task.id,
            succeeded: true,
            message: t("清理了 \(removed) 项 · \(Bytes.format(freed))", "Cleared \(removed) items · \(Bytes.format(freed))")
        )
    }
}
