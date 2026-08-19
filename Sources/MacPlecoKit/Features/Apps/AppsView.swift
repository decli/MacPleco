import SwiftUI
import AppKit

struct AppsView: View {
    @Environment(AppModel.self) private var model

    private var apps: AppsModel { model.apps }

    private var visibleApps: [InstalledApp] {
        apps.visibleApps(registry: model.registry)
    }

    var body: some View {
        @Bindable var apps = model.apps

        Page(destination: .apps, trailing: AnyView(tabPicker)) {
            switch apps.tab {
            case .installed:
                installedControls.rises(0)
                selectionBar.rises(1)
                installedList
            case .startup:
                startupIntro.rises(0)
                startupControls.rises(1)
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
        .sheet(item: $apps.batchPlan) { plan in
            BatchUninstallSheet(
                plan: plan,
                isWorking: apps.isUninstalling,
                progress: apps.uninstallProgress,
                onToggleApp: { apps.toggleBatchApp($0) },
                onToggleLeftover: { apps.toggleBatchLeftover(appID: $0, leftoverID: $1) },
                onCancel: { apps.cancelUninstall() },
                onConfirm: {
                    Task {
                        await apps.confirmBatchUninstall(
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
            SearchField(
                text: $apps.query,
                prompt: t("搜索应用", "Search apps")
            )
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
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: apps.isSizing)
    }

    /// Always present, never hidden behind a hover or a prior selection.
    /// Uninstalling several apps is the reason most people open this page, and
    /// a control that only appears once you have already found it is no
    /// control at all.
    @ViewBuilder
    private var selectionBar: some View {
        let list = visibleApps
        if !list.isEmpty {
            SelectionBar(
                selectedCount: apps.selectedCount,
                totalCount: list.filter(apps.isSelectable).count,
                allSelected: apps.allSelected(in: list),
                onToggleAll: {
                    withAnimation(.smooth(duration: 0.25)) {
                        apps.toggleSelectAll(in: list)
                    }
                }
            ) {
                if apps.selectedCount > 0 {
                    Button(t("清除", "Clear")) {
                        withAnimation(.smooth(duration: 0.25)) { apps.clearSelection() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
                }

                Button {
                    Task { await apps.prepareBatchPlan(registry: model.registry) }
                } label: {
                    HStack(spacing: Space.sm) {
                        if apps.isPlanning, let progress = apps.planningProgress {
                            ProgressView().controlSize(.small).tint(.white)
                            Text(
                                t(
                                    "正在核对 \(progress.done)/\(progress.total)",
                                    "Checking \(progress.done)/\(progress.total)"
                                )
                            )
                        } else {
                            Image(systemName: "trash")
                            Text(t("卸载所选", "Uninstall selected"))
                            if apps.selectedCount > 0 {
                                CountPill(apps.selectedCount, tint: Palette.danger)
                            }
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: Palette.danger))
                .disabled(apps.selectedCount == 0 || apps.isPlanning)
                .opacity(apps.selectedCount == 0 ? 0.45 : 1)
                .help(
                    t(
                        "会先列出每个应用的完整清单，确认后才动手。",
                        "Shows the complete list for every app before anything happens."
                    )
                )
            }
        }
    }

    private var installedList: some View {
        let list = visibleApps
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
                        AppRow(
                            app: app,
                            isSelected: apps.isSelected(app),
                            isSelectable: apps.isSelectable(app),
                            isPlanning: apps.isPlanning,
                            onToggleSelection: {
                                withAnimation(.smooth(duration: 0.2)) {
                                    apps.toggleSelection(app)
                                }
                            },
                            onUninstall: {
                                Task { await apps.preparePlan(for: app) }
                            }
                        )
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

    private var startupControls: some View {
        @Bindable var apps = model.apps
        return HStack(spacing: Space.md) {
            SearchField(
                text: $apps.startupQuery,
                prompt: t("搜索名称或标识", "Search name or label")
            )
            .frame(maxWidth: 260)

            HStack(spacing: Space.sm) {
                Text(t("排序", "Sort"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
                Picker("", selection: $apps.startupSort) {
                    ForEach(AppsModel.StartupSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }

            Spacer()

            if apps.runsAtLoadCount > 0 {
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(Palette.caution)
                        .frame(width: 5, height: 5)
                    Text(
                        t(
                            "\(apps.runsAtLoadCount) 项开机即启动",
                            "\(apps.runsAtLoadCount) run at login"
                        )
                    )
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }

    private var startupList: some View {
        let items = apps.visibleLoginItems
        return Group {
            if apps.isLoadingStartup {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    Text(t("正在读取…", "Reading…"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.vertical, Space.xl)
            } else if items.isEmpty {
                RestfulState(
                    title: apps.loginItems.isEmpty
                        ? t("没有第三方开机项", "No third-party login items")
                        : t("没有匹配的开机项", "No matching login items"),
                    message: apps.loginItems.isEmpty
                        ? t("开机时没有额外的后台程序在等着启动。", "Nothing extra is queued to launch when you start up.")
                        : t("换个关键词试试。", "Try a different search.")
                )
            } else {
                LazyVStack(spacing: Space.sm) {
                    ForEach(items) { item in
                        LoginItemRow(item: item) {
                            Task { await apps.removeLoginItem(item) }
                        }
                    }
                }
                .animation(.smooth(duration: 0.3), value: items.map(\.id))
            }
        }
    }
}

// MARK: - Search field

/// The app's one search control, so every page's search looks and clears the
/// same way.
struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkTertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .glassSurface(Capsule(style: .continuous))
        .animation(.smooth(duration: 0.2), value: text.isEmpty)
    }
}

// MARK: - App row

private struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let isSelectable: Bool
    let isPlanning: Bool
    let onToggleSelection: () -> Void
    let onUninstall: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            if isSelectable {
                TriStateBox(state: isSelected ? .on : .off, action: onToggleSelection)
            } else {
                Color.clear.frame(width: 17, height: 17)
            }

            Image(nsImage: IconCache.shared.icon(forPath: app.path))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: Space.sm) {
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Text(lastUsedText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(idleTint)
                }
            }

            Spacer(minLength: Space.md)

            Text(app.size > 0 ? Bytes.format(app.size) : "—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 74, alignment: .trailing)

            if app.isSystem {
                Text(t("系统自带", "System"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(Palette.wellFill) }
                    .frame(width: 92, alignment: .trailing)
            } else {
                // Permanently visible. Hiding it until hover meant the page
                // looked like it could not uninstall anything at all.
                HStack(spacing: Space.xs) {
                    Button {
                        Removal.revealInFinder(app.url)
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.flow)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1 : 0)
                    .help(t("在访达中显示", "Show in Finder"))

                    Button(t("卸载", "Uninstall"), action: onUninstall)
                        .buttonStyle(GhostButtonStyle(tint: Palette.danger))
                        .disabled(isPlanning)
                }
                .frame(width: 92, alignment: .trailing)
                .animation(.smooth(duration: 0.18), value: isHovering)
            }
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .overlay {
            // A selected row says so on its own edge, so a long list still
            // reads at a glance once it is scrolled away from the checkboxes.
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.aqua.opacity(isSelected ? 0.55 : 0), lineWidth: 1.5)
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.aqua.opacity(isSelected ? 0.08 : (isHovering ? 0.04 : 0)))
        }
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.2), value: isSelected)
        .animation(.smooth(duration: 0.2), value: isHovering)
        .contentShape(Rectangle())
        .onTapGesture { if isSelectable { onToggleSelection() } }
        .contextMenu {
            Button {
                Removal.revealInFinder(app.url)
            } label: {
                Label(t("在访达中显示", "Show in Finder"), systemImage: "folder")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.path, forType: .string)
            } label: {
                Label(t("复制完整路径", "Copy Full Path"), systemImage: "doc.on.doc")
            }
            if !app.isSystem {
                Divider()
                Button(t("卸载…", "Uninstall…"), role: .destructive, action: onUninstall)
            }
        }
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.caution)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2.5)
                    .background { Capsule().fill(Palette.caution.opacity(0.14)) }
            }

            Button {
                Removal.revealInFinder(item.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.flow)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .help(t("在访达中显示", "Show in Finder"))

            if item.isUserScope {
                Button(t("移除", "Remove"), action: onRemove)
                    .buttonStyle(GhostButtonStyle(tint: Palette.danger))
            } else {
                Text(t("需系统设置", "System-wide"))
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.aqua.opacity(isHovering ? 0.04 : 0))
        }
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.2), value: isHovering)
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
                                LeftoverRow(leftover: leftover) { onToggle(leftover.id) }
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

    private var footer: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("共释放 \(Bytes.format(plan.totalSize))", "Frees \(Bytes.format(plan.totalSize))"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
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
        .animation(.smooth(duration: 0.3), value: plan.totalSize)
    }
}

// MARK: - Batch uninstall sheet

/// A batch keeps the same promise a single uninstall makes: nothing goes
/// without being shown first. Every app can be unticked, and every leftover
/// inside every app can still be unticked individually.
private struct BatchUninstallSheet: View {
    let plan: BatchUninstallPlan
    let isWorking: Bool
    let progress: (done: Int, total: Int)?
    let onToggleApp: (String) -> Void
    let onToggleLeftover: (String, String) -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            ScrollView {
                LazyVStack(spacing: Space.sm) {
                    ForEach(plan.plans) { entry in
                        appBlock(entry)
                    }
                }
                .padding(.trailing, Space.xs)
            }
            .frame(maxHeight: 340)

            Divider().overlay(Palette.hairline)

            footer
        }
        .padding(Space.xl)
        .frame(width: 620)
        .background {
            Palette.tankGradient.ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "trash")
                .font(.system(size: 20))
                .foregroundStyle(Palette.danger)
                .frame(width: 44, height: 44)
                .background { Circle().fill(Palette.danger.opacity(0.12)) }

            VStack(alignment: .leading, spacing: 2) {
                Text(t("卸载 \(plan.appCount) 个应用", "Uninstall \(plan.appCount) apps"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(
                    t(
                        "连同它们留下的 \(plan.leftoverCount) 处数据。逐项都可以取消勾选。",
                        "Along with \(plan.leftoverCount) leftovers they created. Anything here can be unticked."
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
        }
    }

    private func appBlock(_ entry: UninstallPlan) -> some View {
        let included = plan.includes(entry.id)
        let isOpen = expanded.contains(entry.id)

        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.md) {
                TriStateBox(state: included ? .on : .off) { onToggleApp(entry.id) }

                Image(nsImage: IconCache.shared.icon(forPath: entry.app.path))
                    .resizable()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.app.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(
                        entry.leftovers.isEmpty
                            ? t("没有其他残留", "No leftovers")
                            : t(
                                "本体 \(Bytes.format(entry.bundleSize)) · 残留 \(entry.leftovers.count) 处 \(Bytes.format(entry.leftoverSize))",
                                "Bundle \(Bytes.format(entry.bundleSize)) · \(entry.leftovers.count) leftovers \(Bytes.format(entry.leftoverSize))"
                            )
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
                }

                Spacer(minLength: Space.sm)

                Text(Bytes.format(entry.totalSize))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(included ? Palette.ink : Palette.inkFaint)

                if !entry.leftovers.isEmpty {
                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            if isOpen { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                    .help(t("查看这些残留", "Show these leftovers"))
                }
            }

            if isOpen {
                VStack(spacing: 0) {
                    ForEach(entry.leftovers) { leftover in
                        LeftoverRow(leftover: leftover, compact: true) {
                            onToggleLeftover(entry.id, leftover.id)
                        }
                    }
                }
                .padding(.leading, Space.xl + Space.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.wellFill)
        }
        .opacity(included ? 1 : 0.5)
        .animation(.smooth(duration: 0.2), value: included)
    }

    private var footer: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("共释放 \(Bytes.format(plan.totalSize))", "Frees \(Bytes.format(plan.totalSize))"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
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
                    if let progress, isWorking {
                        Text(
                            t(
                                "正在卸载 \(progress.done)/\(progress.total)",
                                "Uninstalling \(progress.done)/\(progress.total)"
                            )
                        )
                        .monospacedDigit()
                    } else {
                        Text(t("卸载 \(plan.appCount) 个", "Uninstall \(plan.appCount)"))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: Palette.danger))
            .disabled(isWorking || plan.appCount == 0)
            .opacity(plan.appCount == 0 ? 0.5 : 1)
        }
        .animation(.smooth(duration: 0.3), value: plan.totalSize)
    }
}

// MARK: - Leftover row

private struct LeftoverRow: View {
    let leftover: Leftover
    var compact: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Space.md) {
            TriStateBox(state: leftover.isSelected ? .on : .off, action: onToggle)
            VStack(alignment: .leading, spacing: 1) {
                Text(leftover.kind)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text(leftover.displayPath)
                    .font(.system(size: compact ? 9.5 : 10))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(leftover.url.path)
            }
            Spacer(minLength: Space.sm)
            Button {
                Removal.revealInFinder(leftover.url)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.flow)
            }
            .buttonStyle(.plain)
            .help(t("在访达中显示", "Show in Finder"))
            Text(Bytes.format(leftover.size))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.vertical, compact ? Space.xs : Space.sm)
    }
}
