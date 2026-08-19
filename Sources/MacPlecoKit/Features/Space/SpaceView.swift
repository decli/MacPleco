import SwiftUI
import AppKit

struct SpaceView: View {
    @Environment(AppModel.self) private var model

    /// Which tile or card the pointer is on, and which of the two set it.
    /// The source matters: the map and the list below it share one highlight
    /// so they stay linked, and without knowing who is holding it, the map's
    /// own exit event can arrive after the list's enter event and wipe out a
    /// highlight the pointer is still sitting on.
    @State private var hovered: String?
    @State private var hoverSource: HoverSource?
    @State private var pendingTrash: SpaceEntry?
    @State private var pendingLargeTrash: LargeFile?

    private var space: SpaceModel { model.space }

    var body: some View {
        @Bindable var space = model.space

        VStack(alignment: .leading, spacing: Space.lg) {
            switch space.tab {
            case .map: mapMode
            case .large: largeMode
            }
        }
        .navigationTitle(Destination.space.title)
        .navigationSubtitle(Destination.space.subtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $space.tab) {
                    ForEach(SpaceModel.Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                breadcrumb
                mapOverview
                rankedEntries
                hint
            }
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: 1240 + 2 * Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
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

    // MARK: - Treemap

    private var mapOverview: some View {
        GlassCard(padding: Space.md, radius: Radius.panel) {
            VStack(alignment: .leading, spacing: Space.md) {
                mapHeader
                map
            }
        }
    }

    private var mapHeader: some View {
        HStack(spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(t("本层空间分布", "Storage at this level"))
                Text(
                    t(
                        "面积代表占用空间 · 单击文件夹继续深入",
                        "Area represents size · click a folder to drill down"
                    )
                )
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: Space.md)

            if let item = hoveredMapItem {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(Bytes.format(item.size)) · \(mapShare(item.size))")
                        .font(.system(size: 10.5, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                }
                .transition(.opacity)
            }

            HStack(spacing: Space.md) {
                // Three swatches for folders, because folders are no longer one
                // colour: the legend has to say "any of these" rather than
                // name a hue the map never uses twice.
                mapLegend(colors: Array(Palette.folderTones.prefix(3)), label: t("文件夹", "Folders"))
                mapLegend(colors: [Palette.fileTone], label: t("文件", "Files"))
                if hasTail {
                    mapLegend(colors: [Palette.tailTone], label: t("其他项合计", "Other items"))
                }
            }
        }
        .padding(.horizontal, Space.xs)
    }

    private func mapLegend(colors: [Color], label: String) -> some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 9, height: 9)
                }
            }
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
        }
    }

    /// Whether the long tail was consolidated into its own grey tile.
    private var hasTail: Bool {
        mapItems.contains { $0.entry == nil }
    }

    private var map: some View {
        GeometryReader { geo in
            let visible = mapItems
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
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                    let rect = rects[index]
                    if rect.width > 4, rect.height > 4 {
                        tile(item: item, rect: rect, rank: index)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
            }
            // Tile offsets are coordinates in the map, so their parent must
            // share the same top-leading origin. A centred frame shifts the
            // entire treemap by half the leftover width — the source of the
            // old blank left half and right-edge overflow.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(.smooth(duration: 0.45), value: space.entries)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.wellFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        // A tile only hears about the pointer leaving when the pointer leaves
        // *it*. Slide off the edge of the map, or drill into a folder under
        // the cursor, and the last tile keeps the highlight and the header
        // keeps reading out a tile nothing is pointing at.
        .onHover { inside in
            if !inside, hoverSource == .map { clearHover() }
        }
        .onChange(of: space.currentURL) { clearHover() }
    }

    private func clearHover() {
        hovered = nil
        hoverSource = nil
    }

    /// The heavy items remain individually readable while the long tail is
    /// consolidated into one tile. This keeps tiny, unclickable slivers from
    /// taking over the map and also keeps their combined size honest.
    private var mapItems: [DiskMapItem] {
        let individualLimit = 31
        var items = space.entries.prefix(individualLimit).map(DiskMapItem.init)
        let remainder = space.entries.dropFirst(individualLimit).reduce(Int64(0)) { $0 + $1.size }
        if remainder > 0 {
            items.append(
                DiskMapItem(
                    id: "__other__:\(space.currentURL.path)",
                    name: t("其他 \(space.entries.count - individualLimit) 项", "\(space.entries.count - individualLimit) other items"),
                    size: remainder,
                    entry: nil
                )
            )
        }
        return items
    }

    private var hoveredMapItem: DiskMapItem? {
        guard let hovered else { return nil }
        return mapItems.first { $0.id == hovered }
    }

    private func mapShare(_ size: Int64) -> String {
        guard space.totalSize > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(size) / Double(space.totalSize) * 100)
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

    private func tile(item: DiskMapItem, rect: CGRect, rank: Int) -> some View {
        let isHovered = hovered == item.id
        let showLabel = rect.width > 92 && rect.height > 50
        let prominent = rect.width > 250 && rect.height > 125

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tileColor(item: item, rank: rank).gradient)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.75) : Color.black.opacity(0.15),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
            }
            .overlay(alignment: .topLeading) {
                if showLabel {
                    VStack(alignment: .leading, spacing: prominent ? 6 : 3) {
                        HStack(spacing: 6) {
                            if prominent {
                                Image(systemName: item.entry?.isDirectory == false ? "doc.fill" : "folder.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(item.name)
                        }
                            .font(.system(size: prominent ? 17 : 12.5, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                        Text("\(Bytes.format(item.size)) · \(mapShare(item.size))")
                            .font(.system(size: prominent ? 12.5 : 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .padding(prominent ? Space.lg : Space.sm)
                }
            }
            .padding(2.5)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .scaleEffect(isHovered ? 1.012 : 1, anchor: .center)
            .animation(.smooth(duration: 0.2), value: isHovered)
            .onHover { inside in
                if inside {
                    hovered = item.id
                    hoverSource = .map
                } else if hovered == item.id {
                    clearHover()
                }
            }
            .onTapGesture {
                if let entry = item.entry {
                    if entry.isDirectory {
                        Task { await space.enter(entry) }
                    } else {
                        Removal.revealInFinder(entry.url)
                    }
                }
            }
            .contextMenu {
                if let entry = item.entry { contextMenu(for: entry) }
            }
    }

    /// Colour carries identity, not size. The area of a tile already says how
    /// big it is; the old aqua ramp said it a second time and left every folder
    /// looking like a shade of every other. Each folder now takes the next hue
    /// in the palette, which is ordered so that adjacent tiles — and tiles are
    /// laid out largest first — never land on neighbouring hues. Loose files
    /// keep their own warm tone, and the consolidated tail stays grey.
    private func tileColor(item: DiskMapItem, rank: Int) -> Color {
        guard let entry = item.entry else { return Palette.tailTone }
        guard entry.isDirectory else { return Palette.fileTone }
        return Palette.folderTones[rank % Palette.folderTones.count]
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
        Button(t("复制完整路径", "Copy Full Path")) {
            copyPath(entry.url)
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

    private func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    private var rankedEntries: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                SectionLabel(t("占用最多", "Largest items"))
                Spacer()
                Text(t("前 12 项 · 与地图联动", "Top 12 · linked to the map"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.inkTertiary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 285), spacing: Space.md)],
                spacing: Space.md
            ) {
                if space.entries.isEmpty && space.isScanning {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(radius: Radius.card).frame(height: 76)
                    }
                } else {
                    ForEach(Array(space.entries.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        rankedEntry(entry, rank: index + 1)
                    }
                }
            }
        }
    }

    private func rankedEntry(_ entry: SpaceEntry, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 20, height: 20)
                    .background { Circle().fill(Palette.wellFill) }

                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isDirectory ? Palette.aqua : Palette.caution)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(verbatim: entry.url.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(entry.url.path)
                }

                Spacer(minLength: Space.xs)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Bytes.format(entry.size))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text(mapShare(entry.size))
                        .font(.system(size: 9.5, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }

                Button {
                    Removal.revealInFinder(entry.url)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(Palette.flow)
                .help(t("在访达中显示", "Show in Finder"))
            }

            CapacityBar(
                fraction: space.totalSize > 0 ? Double(entry.size) / Double(space.totalSize) : 0,
                tint: entry.isDirectory ? Palette.aqua : Palette.caution,
                height: 3
            )
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            if entry.isDirectory {
                Task { await space.enter(entry) }
            } else {
                Removal.revealInFinder(entry.url)
            }
        }
        .onHover { inside in
            if inside {
                hovered = entry.id
                hoverSource = .list
            } else if hovered == entry.id {
                clearHover()
            }
        }
        .contextMenu { contextMenu(for: entry) }
    }

    // MARK: - Large files mode

    private var largeMode: some View {
        ScrollView {
            // Lazy on purpose: up to 120 rows land in one update when the scan
            // finishes, and building them all at once (each with a glass pane
            // and an icon) stalled the main thread visibly.
            LazyVStack(alignment: .leading, spacing: Space.md) {
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
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: 1140 + 2 * Space.xxl)
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
                            "常用文件夹里超过 100 MB 的文件，按大小排列。每项都显示完整路径，并可先在访达中确认。",
                            "Files over 100 MB in everyday folders, largest first. Every row shows its full path and opens in Finder for verification."
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
    // The Launch Services icon lookup reads the disk; done in body it turns a
    // page of rows into one long main-thread stall. Fetched async instead,
    // with a quiet placeholder until it lands.
    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: Space.md) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(width: 30, height: 30)
            .task(id: file.id) {
                let path = file.url.path
                icon = await Task.detached(priority: .utility) {
                    let image = NSWorkspace.shared.icon(forFile: path)
                    image.size = NSSize(width: 60, height: 60)
                    return image
                }.value
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(verbatim: file.url.path)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(file.url.path)

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

            Text(Bytes.format(file.size))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 76, alignment: .trailing)

            Button {
                Removal.revealInFinder(file.url)
            } label: {
                Label(t("访达", "Finder"), systemImage: "folder")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(Palette.flow)
            .help(t("在访达中显示", "Show in Finder"))
            .accessibilityLabel(t("在访达中显示 \(file.name)", "Show \(file.name) in Finder"))

            if hovering {
                if canTrash {
                    Button(t("移到废纸篓", "Trash"), action: onTrash)
                        .buttonStyle(GhostButtonStyle(tint: Palette.danger))
                }
            }
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.card)
        .onHover { hovering = $0 }
        .contextMenu {
            Button {
                Removal.revealInFinder(file.url)
            } label: {
                Label(t("在访达中显示", "Show in Finder"), systemImage: "folder")
            }
            Button(action: copyFullPath) {
                Label(t("复制完整路径", "Copy Full Path"), systemImage: "doc.on.doc")
            }
            if canTrash {
                Divider()
                Button(t("移到废纸篓…", "Move to Trash…"), role: .destructive, action: onTrash)
            }
        }
    }

    private var isStale: Bool {
        guard let modified = file.modified else { return false }
        return Date().timeIntervalSince(modified) > 365 * 86_400
    }

    private func copyFullPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.url.path, forType: .string)
    }
}

// MARK: - Map item

/// Which surface put the current highlight up. Both the map and the Top 12
/// cards write to the same `hovered` id so that hovering either one lights up
/// the other; the source keeps the map's exit handler from clearing a
/// highlight the list has just taken over.
private enum HoverSource {
    case map
    case list
}

private struct DiskMapItem: Identifiable {
    let id: String
    let name: String
    let size: Int64
    let entry: SpaceEntry?

    init(_ entry: SpaceEntry) {
        id = entry.id
        name = entry.name
        size = entry.size
        self.entry = entry
    }

    init(id: String, name: String, size: Int64, entry: SpaceEntry?) {
        self.id = id
        self.name = name
        self.size = size
        self.entry = entry
    }
}
