import SwiftUI
import AppKit

struct AppsView: View {
    @Environment(AppModel.self) private var model

    private var apps: AppsModel { model.apps }

    var body: some View {
        @Bindable var apps = model.apps

        Page(destination: .apps, trailing: AnyView(tabPicker)) {
            switch apps.tab {
            case .installed:
                installedControls
                installedList
            case .startup:
                startupIntro
                startupList
            }
        }
        .task {
            await apps.load(registry: model.registry)
        }
        .task(id: apps.tab) {
            if apps.tab == .startup { await apps.loadStartup() }
        }
        .sheet(item: $apps.plan) { plan in
            UninstallSheet(
                plan: plan,
                isWorking: apps.isUninstalling,
                onToggle: { apps.toggleLeftover($0) },
                onCancel: { apps.cancelUninstall() },
                onConfirm: {
                    Task {
                        await apps.confirmUninstall(
                            registry: model.registry,
                            storage: model.storage
                        )
                    }
                }
            )
        }
    }

    private var tabPicker: some View {
        @Bindable var apps = model.apps
        return Picker("", selection: $apps.tab) {
            ForEach(AppsModel.Tab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }

    // MARK: - Installed

    private var installedControls: some View {
        @Bindable var apps = model.apps
        return HStack(spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
                TextField(t("搜索应用", "Search apps"), text: $apps.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .glassSurface(Capsule(style: .continuous))
            .frame(maxWidth: 260)

            Picker("", selection: $apps.sort) {
                ForEach(AppsModel.SortKey.allCases) { key in
                    Text(key.title).tag(key)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 130)

            Toggle(isOn: $apps.showSystemApps) {
                Text(t("含系统自带", "Include system apps"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Spacer()

            if apps.isSizing {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    Text(t("正在计算体积…", "Measuring sizes…"))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }

    private var installedList: some View {
        let list = apps.visibleApps(registry: model.registry)
        return Group {
            if list.isEmpty {
                RestfulState(
                    symbol: "magnifyingglass",
                    title: t("没有匹配的应用", "No matching apps"),
                    message: t("换个关键词试试。", "Try a different search.")
                )
            } else {
                LazyVStack(spacing: Space.sm) {
                    ForEach(list) { app in
                        AppRow(app: app, isPlanning: apps.isPlanning) {
                            Task { await apps.preparePlan(for: app) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Startup

    private var startupIntro: some View {
        GlassCard(padding: Space.lg, radius: Radius.card) {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: "bolt.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.flow)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(t("开机时自动启动的后台程序", "Background programs that start with your Mac"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(
                        t(
                            "多数是应用的更新器或辅助进程。带锁的属于系统范围，需要在「系统设置 › 通用 › 登录项」里处理。",
                            "Most are updaters or helpers belonging to apps. Locked entries are system-wide — handle those in System Settings › General › Login Items."
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.sm)
                Button(t("打开登录项设置", "Open Login Items")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        _ = NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var startupList: some View {
        Group {
            if apps.isLoadingStartup {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    Text(t("正在读取…", "Reading…"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.vertical, Space.xl)
            } else if apps.loginItems.isEmpty {
                RestfulState(
                    title: t("没有第三方开机项", "No third-party login items"),
                    message: t("开机时没有额外的后台程序在等着启动。", "Nothing extra is queued to launch when you start up.")
                )
            } else {
                LazyVStack(spacing: Space.sm) {
                    ForEach(apps.loginItems) { item in
                        LoginItemRow(item: item) {
                            Task { await apps.removeLoginItem(item) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - App row

private struct AppRow: View {
    let app: InstalledApp
    let isPlanning: Bool
    let onUninstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            Image(nsImage: IconCache.shared.icon(forPath: app.path))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: Space.sm) {
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Text(lastUsedText)
                        .font(.system(size: 10))
                        .foregroundStyle(idleTint)
                }
            }

            Spacer(minLength: Space.md)

            if app.isSystem {
                Text(t("系统自带", "System"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 3)
                    .background {
                        Capsule().fill(Palette.wellFill)
                    }
            } else if isHovering {
                Button(t("卸载", "Uninstall"), action: onUninstall)
                    .buttonStyle(GhostButtonStyle(tint: Palette.danger))
                    .disabled(isPlanning)
            }

            Text(app.size > 0 ? Bytes.format(app.size) : "—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 74, alignment: .trailing)
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .onHover { isHovering = $0 }
    }

    private var lastUsedText: String {
        guard let lastUsed = app.lastUsed else { return t("从未打开", "Never opened") }
        return t("\(RelativeTime.describe(lastUsed))用过", "Used \(RelativeTime.describe(lastUsed).lowercased())")
    }

    /// Apps untouched for half a year are the ones worth a second look, so the
    /// date earns a colour. Everything more recent stays quiet.
    private var idleTint: Color {
        let cutoff = Date().addingTimeInterval(-180 * 86_400)
        return (app.lastUsed ?? .distantPast) < cutoff ? Palette.caution : Palette.inkTertiary
    }
}

// MARK: - Login item row

private struct LoginItemRow: View {
    let item: LoginItem
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: item.isUserScope ? "person.crop.circle" : "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(item.isUserScope ? Palette.flow : Palette.inkTertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text(item.label)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Space.md)

            if item.runsAtLoad {
                Text(t("开机即启动", "Runs at login"))
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.caution)
            }

            if isHovering {
                Button {
                    Removal.revealInFinder(item.url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.flow)
                }
                .buttonStyle(.plain)
                .help(t("在访达中显示", "Show in Finder"))
            }

            if item.isUserScope {
                Button(t("移除", "Remove"), action: onRemove)
                    .buttonStyle(GhostButtonStyle(tint: Palette.danger))
                    .opacity(isHovering ? 1 : 0.35)
            } else {
                Text(t("需系统设置", "System-wide"))
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Uninstall sheet

private struct UninstallSheet: View {
    let plan: UninstallPlan
    let isWorking: Bool
    let onToggle: (String) -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            if plan.leftovers.isEmpty {
                Text(
                    t(
                        "这个应用没有在其他地方留下数据。",
                        "This app hasn't left anything else behind."
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: Space.sm) {
                    SectionLabel(
                        t(
                            "还会一并清理这些（共 \(Bytes.format(plan.leftoverSize))）",
                            "These will go too (\(Bytes.format(plan.leftoverSize)))"
                        )
                    )
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(plan.leftovers) { leftover in
                                leftoverRow(leftover)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }

            Divider().overlay(Palette.hairline)

            footer
        }
        .padding(Space.xl)
        .frame(width: 520)
        .background {
            Palette.tankGradient.ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            Image(nsImage: IconCache.shared.icon(forPath: plan.app.path))
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(t("卸载 \(plan.app.name)", "Uninstall \(plan.app.name)"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(
                    t(
                        "应用本体 \(Bytes.format(plan.bundleSize))",
                        "App bundle \(Bytes.format(plan.bundleSize))"
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
        }
    }

    private func leftoverRow(_ leftover: Leftover) -> some View {
        HStack(spacing: Space.md) {
            TriStateBox(state: leftover.isSelected ? .on : .off) {
                onToggle(leftover.id)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(leftover.kind)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text(leftover.displayPath)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Space.sm)
            Text(Bytes.format(leftover.size))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.vertical, Space.sm)
    }

    private var footer: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("共释放 \(Bytes.format(plan.totalSize))", "Frees \(Bytes.format(plan.totalSize))"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(t("全部移到废纸篓，可以恢复。", "All moved to the Trash — recoverable."))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
            Button(t("取消", "Cancel"), action: onCancel)
                .buttonStyle(GhostButtonStyle())
                .disabled(isWorking)
            Button(action: onConfirm) {
                HStack(spacing: Space.sm) {
                    if isWorking {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(t("卸载", "Uninstall"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: Palette.danger))
            .disabled(isWorking)
        }
    }
}
