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

        Page(
            destination: .apps,
            // The two tabs do genuinely different jobs, so the header says
            // which one you are in rather than naming both at once.
            subtitle: apps.tab == .installed
                ? t("卸载应用，连同它留在别处的文件", "Uninstall apps, along with what they left elsewhere")
                : t("管理开机时自动启动的后台程序", "Manage what starts up with your Mac"),
            // The slot holds one control, and never navigation: the tabs moved
            // down to the content, so this page's page-scoped control is the
            // shortcut into System Settings that used to hang off the note.
            trailing: apps.tab == .startup ? AnyView(loginItemsButton) : nil,
            note: apps.tab == .startup ? AnyView(startupNote) : nil,
            tabs: AnyView(PageTabs($apps.tab))
        ) {
            switch apps.tab {
            case .installed:
                installedControls.rises(0)
                selectionBar.rises(1)
                installedList
            case .startup:
                startupControls.rises(0)
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

    private var loginItemsButton: some View {
        Button(t("打开登录项设置", "Open Login Items")) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                _ = NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(ActionButtonStyle(.neutral))
    }

    // MARK: - Installed

    /// Search, sort and scope, all at one height and one type size.
    ///
    /// This is the row the standard was written for: it used to be a 31pt
    /// search field at 12pt beside a 24pt popup at 13pt beside a 24pt mini
    /// switch at 11pt. `FilterRow` imposes the tier; none of the three
    /// controls carries a size any more.
    private var installedControls: some View {
        @Bindable var apps = model.apps
        return FilterRow {
            SearchField(
                text: $apps.query,
                prompt: t("搜索应用", "Search apps")
            )

            MenuChoice($apps.sort, width: 150)

            ChoiceToggle(
                t("含系统自带", "Include system apps"),
                isOn: $apps.showSystemApps
            )

            Spacer()

            if apps.isSizing {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    Text(t("正在计算体积…", "Measuring sizes…"))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.state, value: apps.isSizing)
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
                // How much a batch will remove is the thing worth knowing
                // before running one, not after.
                impact: impactReading,
                onToggleAll: {
                    withAnimation(Motion.state) {
                        apps.toggleSelectAll(in: list)
                    }
                }
            ) {
                if apps.selectedCount > 0 {
                    Button(t("清除", "Clear")) {
                        withAnimation(Motion.state) { apps.clearSelection() }
                    }
                    .buttonStyle(TextButtonStyle(.quiet))
                }

                Button {
                    Task { await apps.prepareBatchPlan(registry: model.registry) }
                } label: {
                    HStack(spacing: Space.sm) {
                        if apps.isPlanning, let progress = apps.planningProgress {
                            ProgressView().controlSize(.small)
                            Text(
                                t(
                                    "正在核对 \(progress.done)/\(progress.total)",
                                    "Checking \(progress.done)/\(progress.total)"
                                )
                            )
                        } else {
                            Image(systemName: "trash").glyph(.control)
                            Text(t("卸载所选", "Uninstall selected"))
                            if apps.selectedCount > 0 {
                                Badge.count(apps.selectedCount, tint: Palette.danger)
                            }
                        }
                    }
                }
                // Irreversible, and only a proposal: it opens a sheet listing
                // everything first. Outlined in danger, not a filled pink
                // block — the filled version was both the loudest thing on
                // the page and, at 2.6:1, the hardest to read.
                .buttonStyle(ActionButtonStyle(.destructive))
                .actionEnabled(apps.selectedCount > 0 && !apps.isPlanning)
                .help(
                    t(
                        "会先列出每个应用的完整清单，确认后才动手。",
                        "Shows the complete list for every app before anything happens."
                    )
                )
            }
        }
    }

    /// The weight of the current selection, or nothing when it is empty.
    private var impactReading: String? {
        let size = apps.selectedSize(registry: model.registry)
        return size > 0 ? Bytes.format(size) : nil
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

    /// What used to be a `GlassCard` restating the page. A caveat is not a
    /// card: it belongs with the heading, at caption size, not competing with
    /// the login items it is describing. Its button moved to the masthead
    /// slot, which is where a page-scoped control goes — and which is what
    /// lets this line stay exactly one line tall on every page.
    private var startupNote: some View {
        PageNote(
            symbol: "bolt.badge.clock",
            t(
                "多数是应用的更新器或辅助进程。带锁的属于系统范围，需要在「系统设置 › 通用 › 登录项」里处理。",
                "Most are updaters or helpers belonging to apps. Locked entries are system-wide — handle those in System Settings › General › Login Items."
            )
        )
    }

    private var startupControls: some View {
        @Bindable var apps = model.apps
        return FilterRow {
            SearchField(
                text: $apps.startupQuery,
                prompt: t("搜索名称或标识", "Search name or label")
            )

            SegmentedChoice($apps.startupSort)

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
                    .font(Typo.caption)
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
                        .font(Typo.labelPlain)
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
                RowLeadingSpacer()
            }

            Image(nsImage: IconCache.shared.icon(forPath: app.path))
                .resizable()
                .frame(width: Layout.rowIcon, height: Layout.rowIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(Typo.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: Space.sm) {
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Text(lastUsedText)
                        .font(Typo.caption)
                        .foregroundStyle(idleTint)
                }
            }

            Spacer(minLength: Space.md)

            Group {
                if app.size > 0 {
                    Reading(bytes: app.size, tint: Palette.inkSecondary)
                } else {
                    Text("—").font(Typo.labelNumeric).foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(width: Layout.valueColumn, alignment: .trailing)

            if app.isSystem {
                Badge(t("系统自带", "System"))
                    .frame(width: Layout.actionColumn, alignment: .trailing)
            } else {
                // Permanently visible. Hiding it until hover meant the page
                // looked like it could not uninstall anything at all.
                HStack(spacing: Space.xs) {
                    IconButton("folder", help: t("在访达中显示", "Show in Finder")) {
                        Removal.revealInFinder(app.url)
                    }
                    .opacity(isHovering ? 1 : 0)

                    Button(t("卸载", "Uninstall"), action: onUninstall)
                        .buttonStyle(ActionButtonStyle(.destructive, height: Control.compact))
                        .actionEnabled(!isPlanning)
                }
                .frame(width: Layout.actionColumn, alignment: .trailing)
                .animation(Motion.hover, value: isHovering)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.standardRow)
        .glassPanel(radius: Radius.card)
        .rowSelection(isSelected, hovering: isHovering)
        .onHover { isHovering = $0 }
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
            RowLeadingSpacer()
            Image(systemName: item.isUserScope ? "person.crop.circle" : "lock.fill")
                .glyph(.row)
                .foregroundStyle(item.isUserScope ? Palette.flow : Palette.inkTertiary)
                .frame(width: Layout.rowIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(Typo.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(item.label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Space.md)

            if item.runsAtLoad {
                Badge(t("开机即启动", "Runs at login"), style: .tinted(Palette.caution))
            }

            IconButton("arrow.up.forward.app", help: t("在访达中显示", "Show in Finder")) {
                Removal.revealInFinder(item.url)
            }
            .opacity(isHovering ? 1 : 0)

            Group {
                if item.isUserScope {
                    Button(t("移除", "Remove"), action: onRemove)
                        .buttonStyle(ActionButtonStyle(.destructive, height: Control.compact))
                } else {
                    Text(t("需系统设置", "System-wide"))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .frame(width: Layout.actionColumn, alignment: .trailing)
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.standardRow)
        .glassPanel(radius: Radius.card)
        .rowSelection(false, hovering: isHovering)
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
                .font(Typo.labelPlain)
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
        // The one kind of place a filled danger button is allowed to exist:
        // the user has already asked for this, and nothing else here competes
        // with it. Outside a surface marked like this, `.confirm` renders as
        // an ordinary outlined destructive button.
        .confirmationSurface()
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            Image(nsImage: IconCache.shared.icon(forPath: plan.app.path))
                .resizable()
                .frame(width: IconBox.large.side, height: IconBox.large.side)
            VStack(alignment: .leading, spacing: 2) {
                Text(t("卸载 \(plan.app.name)", "Uninstall \(plan.app.name)"))
                    .font(Typo.cardTitle)
                    .foregroundStyle(Palette.ink)
                Text(
                    t(
                        "应用本体 \(Bytes.format(plan.bundleSize))",
                        "App bundle \(Bytes.format(plan.bundleSize))"
                    )
                )
                .font(Typo.labelPlain)
                .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("共释放 \(Bytes.format(plan.totalSize))", "Frees \(Bytes.format(plan.totalSize))"))
                    .font(Typo.bodyNumeric)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Palette.ink)
                Text(t("全部移到废纸篓，可以恢复。", "All moved to the Trash — recoverable."))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
            Button(t("取消", "Cancel"), action: onCancel)
                .buttonStyle(ActionButtonStyle(.neutral))
                .actionEnabled(!isWorking)
            Button(action: onConfirm) {
                HStack(spacing: Space.sm) {
                    if isWorking {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(t("卸载", "Uninstall"))
                }
            }
            .buttonStyle(ActionButtonStyle(.confirm))
            .actionEnabled(!isWorking)
        }
        .animation(Motion.reveal, value: plan.totalSize)
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
        .confirmationSurface()
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            IconTile("trash", box: .large, style: .tinted(Palette.danger))

            VStack(alignment: .leading, spacing: 2) {
                Text(t("卸载 \(plan.appCount) 个应用", "Uninstall \(plan.appCount) apps"))
                    .font(Typo.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(
                    t(
                        "连同它们留下的 \(plan.leftoverCount) 处数据。逐项都可以取消勾选。",
                        "Along with \(plan.leftoverCount) leftovers they created. Anything here can be unticked."
                    )
                )
                .font(Typo.labelPlain)
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
                    .frame(width: IconBox.small.side, height: IconBox.small.side)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.app.name)
                        .font(Typo.label)
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
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                }

                Spacer(minLength: Space.sm)

                Reading(bytes: entry.totalSize, tint: included ? Palette.ink : Palette.inkFaint)

                if !entry.leftovers.isEmpty {
                    IconButton(
                        "chevron.right",
                        tint: Palette.inkTertiary,
                        help: t("查看这些残留", "Show these leftovers")
                    ) {
                        withAnimation(Motion.state) {
                            if isOpen { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
                        }
                    }
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
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
                .padding(.leading, Space.xxl)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.wellFill)
        }
        .opacity(included ? 1 : Motion.disabledOpacity)
        .animation(Motion.state, value: included)
    }

    private var footer: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("共释放 \(Bytes.format(plan.totalSize))", "Frees \(Bytes.format(plan.totalSize))"))
                    .font(Typo.bodyNumeric)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Palette.ink)
                Text(t("全部移到废纸篓，可以恢复。", "All moved to the Trash — recoverable."))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
            Button(t("取消", "Cancel"), action: onCancel)
                .buttonStyle(ActionButtonStyle(.neutral))
                .actionEnabled(!isWorking)
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
            .buttonStyle(ActionButtonStyle(.confirm))
            .actionEnabled(!isWorking && plan.appCount > 0)
        }
        .animation(Motion.reveal, value: plan.totalSize)
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
                    .font(Typo.label)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(leftover.displayPath)
                    .font(Typo.microMono)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(leftover.url.path)
            }
            Spacer(minLength: Space.sm)
            IconButton("folder", help: t("在访达中显示", "Show in Finder")) {
                Removal.revealInFinder(leftover.url)
            }
            Reading(bytes: leftover.size, emphasis: .dense, tint: Palette.inkSecondary)
                .frame(width: Layout.valueColumn, alignment: .trailing)
        }
        .frame(height: Layout.compactRow)
    }
}
