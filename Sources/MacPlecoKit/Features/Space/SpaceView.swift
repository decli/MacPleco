import SwiftUI

struct SpaceView: View {
    @Environment(AppModel.self) private var model

    @State private var hovered: String?
    @State private var pendingTrash: SpaceEntry?
    @State private var pendingLargeTrash: LargeFile?

    private var space: SpaceModel { model.space }

    var body: some View {
        @Bindable var space = model.space

        VStack(alignment: .leading, spacing: Space.lg) {
            PageHeader(title: Destination.space.title, subtitle: Destination.space.subtitle) {
                Picker("", selection: $space.tab) {
                    ForEach(SpaceModel.Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }
            .padding(.horizontal, Space.xxl + Space.sm)
            .padding(.top, Space.xxl + Space.md)

            switch space.tab {
            case .map: mapMode
            case .large: largeMode
            }
        }
        .task { await space.start() }
        .task(id: space.tab) {
            if space.tab == .large { await space.scanLargeIfNeeded() }
        }
        .alert(item: $pendingTrash) { entry in
            trashAlert(name: entry.name, size: entry.size) {
                Task { _ = await space.trash(entry, storage: model.storage) }
            }
        }
        .alert(item: $pendingLargeTrash) { file in
            trashAlert(name: file.name, size: file.size) {
                Task { _ = await space.trashLargeFile(file, storage: model.storage) }
            }
        }
    }

    private func trashAlert(name: String, size: Int64, action: @escaping () -> Void) -> Alert {
        Alert(
            title: Text(t("移到废纸篓？", "Move to Trash?")),
            message: Text(
                t(
                    "「\(name)」（\(Bytes.format(size))）会被移到废纸篓，可以从废纸篓恢复。",
                    "“\(name)” (\(Bytes.format(size))) will be moved to the Trash. You can put it back from there."
                )
            ),
            primaryButton: .destructive(Text(t("移到废纸篓", "Move to Trash")), action: action),
            secondaryButton: .cancel(Text(t("取消", "Cancel")))
        )
    }

    // MARK: - Map mode

    private var mapMode: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            breadcrumb
            HStack(alignment: .top, spacing: Space.lg) {
                sidebar
                map
            }
            hint
        }
        .padding(.horizontal, Space.xxl + Space.sm)
        .padding(.bottom, Space.xl)
    }

    private var breadcrumb: some View {
        HStack(spacing: Space.xs) {
            ForEach(Array(space.trail.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                }
                Button {
                    Task { await space.goTo(index: index) }
                } label: {
                    Text(entry.name)
                        .font(.system(size: 12.5, weight: index == space.trail.count - 1 ? .semibold : .regular))
                        .foregroundStyle(index == space.trail.count - 1 ? Palette.ink : Palette.flow)
                }
                .buttonStyle(.plain)
                .disabled(index == space.trail.count - 1)
            }

            Spacer()

            if space.isScanning {
                HStack(spacing: Space.sm) {
                    ProgressView().controlSize(.small)
                    Text(
                        t(
                            "正在测量 \(space.scanned)/\(space.expected)",
                            "Measuring \(space.scanned)/\(space.expected)"
                        )
                    )
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                }
            } else {
                Button {
                    Task { await space.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .buttonStyle(.plain)
                .help(t("重新测量这一层", "Measure this level again"))

                Text(
                    t(
                        "当前 \(Bytes.format(space.totalSize))",
                        "\(Bytes.format(space.totalSize)) here"
                    )
                )
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 2)
        .glassPanel(radius: Radius.row)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel(t("按大小排列", "By size"))
                .padding(.horizontal, Space.sm)
            ScrollView {
                LazyVStack(spacing: 1) {
                    if space.entries.isEmpty && space.isScanning {
                        ForEach(0..<7, id: \.self) { _ in
                            SkeletonBlock(radius: 6)
                                .frame(height: 22)
                                .padding(.horizontal, Space.sm)
                                .padding(.vertical, 2)
                        }
                    }
                    ForEach(space.entries.prefix(60)) { entry in
                        listRow(entry)
                    }
                }
            }
        }
        .frame(width: 232)
        .padding(Space.md)
        .glassPanel(radius: Radius.panel)
    }

    private func listRow(_ entry: SpaceEntry) -> some View {
        Button {
            if entry.isDirectory {
                Task { await space.enter(entry) }
            } else {
                Removal.revealInFinder(entry.url)
            }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(tint(for: entry))
                Text(entry.name)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Space.xs)
                Text(Bytes.format(entry.size))
                    .font(.system(size: 10.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered == entry.id ? Palette.wellFill : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? entry.id : (hovered == entry.id ? nil : hovered) }
        .contextMenu { contextMenu(for: entry) }
    }

    // MARK: - Treemap

    private var map: some View {
        GeometryReader { geo in
            let visible = Array(space.entries.prefix(40))
            let rects = Treemap.layout(
                values: visible.map(\.size),
                in: CGRect(origin: .zero, size: geo.size)
            )

            ZStack(alignment: .topLeading) {
                if visible.isEmpty {
                    if space.isScanning {
                        skeletonMap(in: geo.size)
                    } else {
                        unreadableState
                    }
                }
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                    let rect = rects[index]
                    if rect.width > 2, rect.height > 2 {
                        tile(entry: entry, rect: rect, rank: index, of: visible.count)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.smooth(duration: 0.45), value: space.entries)
        }
        .frame(maxWidth: .infinity, minHeight: 430, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
    }

    private func skeletonMap(in size: CGSize) -> some View {
        let weights: [CGFloat] = [34, 22, 14, 9, 7, 5, 4, 3, 2]
        let rects = Treemap.layout(values: weights, in: CGRect(origin: .zero, size: size))
        return ZStack(alignment: .topLeading) {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                SkeletonBlock(radius: 7)
                    .padding(1.5)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
            VStack(spacing: Space.sm) {
                ProgressView().controlSize(.small)
                Text(
                    t(
                        "正在测量各个文件夹的大小，测完一个显示一个…",
                        "Measuring folder sizes — each appears as it finishes…"
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
            }
            .padding(Space.lg)
            .glassPanel(radius: Radius.card)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var unreadableState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "eye.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.inkTertiary)
            Text(t("这里读不到内容", "Nothing readable here"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(
                t(
                    "文件夹可能是空的，也可能需要「完全磁盘访问权限」才能读取。",
                    "The folder may be empty, or it may need Full Disk Access to read."
                )
            )
            .font(.system(size: 12))
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            HStack(spacing: Space.md) {
                Button(t("打开权限设置", "Open permission settings")) {
                    model.permissions.openSettings()
                }
                .buttonStyle(GhostButtonStyle(tint: Palette.flow))
                Button(t("重试", "Try again")) {
                    Task { await space.refresh() }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(entry: SpaceEntry, rect: CGRect, rank: Int, of count: Int) -> some View {
        let isHovered = hovered == entry.id
        let showLabel = rect.width > 76 && rect.height > 42

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tileColor(entry: entry, rank: rank, of: count).gradient)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.75) : Color.black.opacity(0.15),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
            }
            .overlay(alignment: .topLeading) {
                if showLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(2)
                        Text(Bytes.format(entry.size))
                            .font(.system(size: 10.5, design: .rounded))
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .padding(Space.sm)
                }
            }
            .padding(1.5)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .scaleEffect(isHovered ? 1.012 : 1, anchor: .center)
            .animation(.smooth(duration: 0.2), value: isHovered)
            .onHover { hovered = $0 ? entry.id : nil }
            .onTapGesture {
                if entry.isDirectory {
                    Task { await space.enter(entry) }
                } else {
                    Removal.revealInFinder(entry.url)
                }
            }
            .contextMenu { contextMenu(for: entry) }
            .help("\(entry.name) · \(Bytes.format(entry.size))")
    }

    /// Colour carries meaning: depth of aqua tracks size rank — the biggest
    /// tiles are the deepest water — and loose files surface in warm tones so
    /// "one huge file" and "a folder of many things" never look alike.
    private func tileColor(entry: SpaceEntry, rank: Int, of count: Int) -> Color {
        if !entry.isDirectory {
            return rank < max(1, count / 3) ? Palette.danger : Palette.caution
        }
        let position = count <= 1 ? 0 : Double(rank) / Double(count - 1)
        let ramp: [Color] = [Palette.aquaDeep, Palette.aqua, Palette.flow, Palette.flow.opacity(0.75)]
        let scaled = position * Double(ramp.count - 1)
        return ramp[min(ramp.count - 1, Int(scaled.rounded()))]
    }

    @ViewBuilder
    private func contextMenu(for entry: SpaceEntry) -> some View {
        if entry.isDirectory {
            Button(t("进入", "Open here")) {
                Task { await space.enter(entry) }
            }
        }
        Button(t("在访达中显示", "Show in Finder")) {
            Removal.revealInFinder(entry.url)
        }
        if space.canTrash(entry.url) {
            Divider()
            Button(t("移到废纸篓…", "Move to Trash…"), role: .destructive) {
                pendingTrash = entry
            }
        }
    }

    private var hint: some View {
        Text(
            t(
                "单击进入文件夹，右键可以在访达中显示或移到废纸篓。",
                "Click a tile to open it; right-click to reveal in Finder or move to Trash."
            )
        )
        .font(.system(size: 11))
        .foregroundStyle(Palette.inkTertiary)
    }

    // MARK: - Large files mode

    private var largeMode: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                largeHeader
                if space.isScanningLarge && space.largeFiles.isEmpty {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(radius: Radius.card).frame(height: 56)
                    }
                } else if space.largeFiles.isEmpty {
                    RestfulState(
                        symbol: "sparkle.magnifyingglass",
                        title: t("没有值得注意的大文件", "No large files worth flagging"),
                        message: t(
                            "常用文件夹里没有超过 100 MB 的文件。",
                            "Nothing over 100 MB is sitting in your everyday folders."
                        )
                    )
                } else {
                    ForEach(space.largeFiles) { file in
                        LargeFileRow(file: file, canTrash: space.canTrash(file.url)) {
                            pendingLargeTrash = file
                        }
                    }
                }
            }
            .padding(.horizontal, Space.xxl + Space.sm)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: 1140 + 2 * (Space.xxl + Space.sm))
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
    }

    private var largeHeader: some View {
        GlassCard(padding: Space.md, radius: Radius.card) {
            HStack(spacing: Space.md) {
                Image(systemName: "doc.badge.clock")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.flow)
                Text(
                    space.isScanningLarge
                        ? t(
                            "正在翻看常用文件夹… 已看过 \(space.largeFilesScanned) 个文件",
                            "Looking through your everyday folders… \(space.largeFilesScanned) files so far"
                          )
                        : t(
                            "常用文件夹里超过 100 MB 的文件，按大小排列。隐藏目录和缓存归「清理」管，不在这里。",
                            "Files over 100 MB in your everyday folders, largest first. Hidden folders and caches belong to Clean, not here."
                          )
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: 0)
                if space.isScanningLarge {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await space.scanLarge() }
                    } label: {
                        Label(t("重新查找", "Look again"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }
}

// MARK: - Large file row

private struct LargeFileRow: View {
    let file: LargeFile
    let canTrash: Bool
    let onTrash: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            Image(nsImage: IconCache.shared.icon(forPath: file.url.path))
                .resizable()
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: Space.sm) {
                    Text(file.folder)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 2)
                        .background { Capsule().fill(Palette.wellFill) }
                    Text(RelativeTime.describe(file.modified))
                        .font(.system(size: 10.5))
                        .foregroundStyle(isStale ? Palette.caution : Palette.inkTertiary)
                }
            }

            Spacer(minLength: Space.md)

            if hovering {
                Button {
                    Removal.revealInFinder(file.url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.flow)
                }
                .buttonStyle(.plain)
                .help(t("在访达中显示", "Show in Finder"))

                if canTrash {
                    Button(t("移到废纸篓", "Trash"), action: onTrash)
                        .buttonStyle(GhostButtonStyle(tint: Palette.danger))
                }
            }

            Text(Bytes.format(file.size))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .onHover { hovering = $0 }
    }

    private var isStale: Bool {
        guard let modified = file.modified else { return false }
        return Date().timeIntervalSince(modified) > 365 * 86_400
    }
}
