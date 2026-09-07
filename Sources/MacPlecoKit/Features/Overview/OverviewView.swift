import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    private var clean: CleanModel { model.clean }
    private var storage: StorageModel { model.storage }

    var body: some View {
        Page(destination: .overview) {
            if !model.permissions.hasFullDiskAccess {
                PermissionCard(permissions: model.permissions)
                    .rises(0)
            }
            hero.rises(1)
            insights.rises(2)
            if model.ledger.totalRuns > 0 {
                ledgerStrip.rises(3)
            }
        }
        .task {
            model.permissions.refresh()
            await clean.scanIfNeeded(registry: model.registry)
            await model.registry.load()
        }
    }

    // MARK: - Hero

    /// The page's one loud moment, and the only filled block in the window.
    ///
    /// Both buttons are `hero`: they are a pair of answers to the same
    /// question, and a pair rendered at two sizes reads as one button plus an
    /// afterthought. The secondary one carries a real edge now — on the pale
    /// ground its outline used to disappear into the card behind it.
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
                            .font(Typo.feature)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(supporting)
                            .font(Typo.body)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }

                    HStack(spacing: Space.md) {
                        Button {
                            clean.selectRecommended()
                            withAnimation(Motion.reveal) {
                                model.destination = .clean
                            }
                        } label: {
                            Label(t("开始清理", "Start cleaning"), systemImage: "sparkles")
                        }
                        // Reversible and affirmative: everything it touches
                        // goes to the Trash first. The one intent allowed to
                        // be the loudest thing on the page.
                        .buttonStyle(ActionButtonStyle(.go, height: Control.hero))
                        .actionEnabled(!clean.isScanning && clean.totalSize > 0)

                        Button(t("看看有哪些", "See what's there")) {
                            withAnimation(Motion.reveal) {
                                model.destination = .clean
                            }
                        }
                        .buttonStyle(ActionButtonStyle(.neutral, height: Control.hero))
                    }

                    Label {
                        Text(
                            t(
                                "清理时所有内容都会先进废纸篓，不会直接删掉。",
                                "Nothing is deleted outright — everything goes to the Trash first."
                            )
                        )
                    } icon: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundStyle(Palette.aqua)
                    }
                    .font(Typo.caption)
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
        StatCardGrid {
            StatCard(
                symbol: "internaldrive",
                label: t("磁盘", "Disk"),
                value: Bytes.format(storage.available),
                detail: t(
                    "可用 · 共 \(Bytes.format(storage.total))",
                    "free of \(Bytes.format(storage.total))"
                ),
                tint: storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua,
                progress: storage.usedFraction
            )

            StatCard(
                symbol: "square.stack.3d.up",
                label: t("已安装应用", "Installed apps"),
                value: "\(model.registry.apps.filter { !$0.isSystem }.count)",
                detail: idleAppsDetail,
                tint: Palette.flow
            )

            StatCard(
                symbol: "clock",
                label: t("已运行", "Uptime"),
                value: RelativeTime.duration(SystemInfo.uptime),
                detail: t("自上次重启", "since last restart"),
                tint: Palette.flow
            )

            StatCard(
                symbol: "cpu",
                label: t("芯片", "Chip"),
                value: chipName,
                detail: t(
                    "\(Bytes.formatMemory(SystemInfo.physicalMemory)) 内存 · macOS \(SystemInfo.osVersion)",
                    "\(Bytes.formatMemory(SystemInfo.physicalMemory)) memory · macOS \(SystemInfo.osVersion)"
                ),
                tint: SystemInfo.thermalState == .nominal ? Palette.positive : Palette.caution,
                badge: SystemInfo.thermalDescription
            )
        }
    }

    private var chipName: String {
        SystemInfo.chip.replacingOccurrences(of: "Apple ", with: "")
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

    // MARK: - Ledger strip

    private var ledgerStrip: some View {
        let ledger = model.ledger
        return GlassCard(padding: Space.lg, radius: Radius.card, tint: Palette.aqua) {
            HStack(spacing: Space.md) {
                Image(systemName: "fish.fill")
                    .glyph(.row)
                    .foregroundStyle(Palette.aqua)
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        t(
                            "MacPleco 已累计为这台 Mac 腾出 \(Bytes.format(ledger.totalBytes))",
                            "MacPleco has freed \(Bytes.format(ledger.totalBytes)) on this Mac so far"
                        )
                    )
                    .font(Typo.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    if let last = ledger.lastRecord {
                        Text(
                            t(
                                "共 \(ledger.totalRuns) 次清理 · 上次是\(RelativeTime.describe(last.date))",
                                "\(ledger.totalRuns) cleans · last one \(RelativeTime.describe(last.date).lowercased())"
                            )
                        )
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
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
                    .glyph(.title)
                    .foregroundStyle(Palette.flow)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(t("还差一步：完全磁盘访问权限", "One step left: Full Disk Access"))
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                    Text(
                        t(
                            "macOS 默认不让任何应用读取其他应用的缓存目录。授权后 MacPleco 才能算出可以清理多少，权限随时可以收回。",
                            "macOS keeps every app out of other apps' cache folders by default. MacPleco needs this to measure what can be cleared, and you can revoke it at any time."
                        )
                    )
                    .font(Typo.labelPlain)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Space.sm)

                VStack(spacing: Space.sm) {
                    // Outlined, not filled: the hero card below already owns
                    // this page's one filled block, and two of them competing
                    // is exactly the noise the standard is trying to remove.
                    Button(t("去设置", "Open Settings")) {
                        permissions.openSettings()
                    }
                    .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))

                    Button(t("我已授权", "I've done it")) {
                        permissions.refresh()
                    }
                    .buttonStyle(TextButtonStyle())
                }
            }
        }
    }
}
