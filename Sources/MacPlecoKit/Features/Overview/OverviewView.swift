import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    private var clean: CleanModel { model.clean }
    private var storage: StorageModel { model.storage }

    var body: some View {
        Page(destination: .overview) {
            if !model.permissions.hasFullDiskAccess {
                PermissionCard(permissions: model.permissions)
            }
            hero
            insights
        }
        .task {
            model.permissions.refresh()
            await clean.scanIfNeeded(registry: model.registry)
            await model.registry.load()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        GlassCard(padding: Space.xl) {
            HStack(alignment: .center, spacing: Space.huge) {
                DepthRing(
                    usedFraction: storage.usedFraction,
                    reclaimableFraction: reclaimableFraction,
                    isWorking: clean.isScanning,
                    caption: clean.isScanning
                        ? t("正在检查", "Checking")
                        : t("可以腾出", "Can free up"),
                    value: Bytes.split(clean.totalSize).number,
                    unit: Bytes.split(clean.totalSize).unit
                )

                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text(headline)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(supporting)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: Space.md) {
                        Button {
                            clean.selectRecommended()
                            model.destination = .clean
                        } label: {
                            HStack(spacing: Space.sm) {
                                Image(systemName: "sparkles")
                                Text(t("开始清理", "Start cleaning"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(clean.isScanning || clean.totalSize == 0)
                        .opacity(clean.isScanning || clean.totalSize == 0 ? 0.5 : 1)

                        Button(t("看看有哪些", "See what's there")) {
                            model.destination = .clean
                        }
                        .buttonStyle(GhostButtonStyle())
                    }

                    Text(
                        t(
                            "清理时所有内容都会先进废纸篓，不会直接删掉。",
                            "Nothing is deleted outright — everything goes to the Trash first."
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var reclaimableFraction: Double {
        guard storage.total > 0 else { return 0 }
        return min(storage.usedFraction, Double(clean.totalSize) / Double(storage.total))
    }

    /// The headline reports; it never pressures. There is no "your Mac is at
    /// risk" state, because it would not be true.
    private var headline: String {
        if clean.isScanning {
            return t("正在看看有什么可以清理…", "Seeing what can be cleared…")
        }
        if clean.totalSize == 0 {
            return t("这台 Mac 挺干净的", "This Mac is in good shape")
        }
        return t(
            "有 \(Bytes.format(clean.totalSize)) 可以回收",
            "\(Bytes.format(clean.totalSize)) can be reclaimed"
        )
    }

    private var supporting: String {
        if clean.isScanning {
            return t(
                "正在读取缓存和日志的大小，不会改动任何文件。",
                "Reading the size of caches and logs. No files are touched."
            )
        }
        if clean.totalSize == 0 {
            return t(
                "没有发现值得清理的缓存或日志。过几天再来看看吧。",
                "Nothing worth clearing turned up. Check back in a few days."
            )
        }
        return t(
            "来自 \(clean.itemCount) 处缓存、日志和残留文件。已经替你选好了安全的那些。",
            "Across \(clean.itemCount) caches, logs and leftovers. The safe ones are already selected for you."
        )
    }

    // MARK: - Insight cards

    private var insights: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 210), spacing: Space.md)],
            spacing: Space.md
        ) {
            InsightCard(
                symbol: "internaldrive",
                label: t("磁盘", "Disk"),
                value: Bytes.format(storage.available),
                detail: t(
                    "可用 · 共 \(Bytes.format(storage.total))",
                    "free of \(Bytes.format(storage.total))"
                ),
                progress: storage.usedFraction,
                tint: storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua
            )

            InsightCard(
                symbol: "square.stack.3d.up",
                label: t("已安装应用", "Installed apps"),
                value: "\(model.registry.apps.filter { !$0.isSystem }.count)",
                detail: idleAppsDetail,
                tint: Palette.flow
            )

            InsightCard(
                symbol: "clock",
                label: t("已运行", "Uptime"),
                value: RelativeTime.duration(SystemInfo.uptime),
                detail: t("自上次重启", "since last restart"),
                tint: Palette.flow
            )

            InsightCard(
                symbol: "cpu",
                label: SystemInfo.chip,
                value: SystemInfo.thermalDescription,
                detail: t(
                    "\(Bytes.format(SystemInfo.physicalMemory)) 内存 · macOS \(SystemInfo.osVersion)",
                    "\(Bytes.format(SystemInfo.physicalMemory)) memory · macOS \(SystemInfo.osVersion)"
                ),
                tint: SystemInfo.thermalState == .nominal ? Palette.positive : Palette.caution
            )
        }
    }

    private var idleAppsDetail: String {
        let cutoff = Date().addingTimeInterval(-180 * 86_400)
        let idle = model.registry.apps.filter { app in
            !app.isSystem && (app.lastUsed ?? .distantPast) < cutoff
        }.count
        if idle == 0 {
            return t("最近都用过", "all used recently")
        }
        return t("其中 \(idle) 个半年没打开", "\(idle) untouched for 6 months")
    }
}

// MARK: - Insight card

struct InsightCard: View {
    let symbol: String
    let label: String
    let value: String
    let detail: String
    var progress: Double?
    var tint: Color = Palette.aqua

    var body: some View {
        GlassCard(padding: Space.lg, radius: Radius.card) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }

                Text(value)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let progress {
                    CapacityBar(fraction: progress, tint: tint, height: 4)
                }

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Permission card

struct PermissionCard: View {
    let permissions: PermissionsModel

    var body: some View {
        GlassCard(padding: Space.lg, tint: Palette.flow) {
            HStack(alignment: .top, spacing: Space.lg) {
                Image(systemName: "lock.open")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.flow)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(t("还差一步：完全磁盘访问权限", "One step left: Full Disk Access"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(
                        t(
                            "macOS 默认不让任何应用读取其他应用的缓存目录。授权后 MacPleco 才能算出可以清理多少，权限随时可以收回。",
                            "macOS keeps every app out of other apps' cache folders by default. MacPleco needs this to measure what can be cleared, and you can revoke it at any time."
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Space.sm)

                VStack(spacing: Space.sm) {
                    Button(t("去设置", "Open Settings")) {
                        permissions.openSettings()
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Palette.flow))

                    Button(t("我已授权", "I've done it")) {
                        permissions.refresh()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.flow)
                }
            }
        }
    }
}
