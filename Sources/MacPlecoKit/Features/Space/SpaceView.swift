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

    /// Where the pointer is inside the map, in the map's own coordinates.
    ///
    /// The map's highlight is derived from this position against the tiles as
    /// they are laid out *now*, rather than remembered from whichever tile
    /// last saw an `onHover`. A tile only hears about the pointer when the
    /// pointer crosses its edge, so anything that moves tiles underneath a
    /// still cursor — a folder finishing its measurement, drilling into the
    /// next level — used to leave the old tile holding the highlight while
    /// the cursor sat on a different one. Position cannot go stale that way:
    /// when the layout changes, the answer is simply recomputed.
    @State private var mapPointer: CGPoint?
    @State private var pendingTrash: SpaceEntry?
    @State private var pendingLargeTrash: LargeFile?

    private var space: SpaceModel { model.space }

    var body: some View {
        @Bindable var space = model.space

        Page(
            destination: .space,
            subtitle: space.tab == .map
                ? Destination.space.subtitle
                : t(
                    "常用文件夹里超过 100 MB 的文件",
                    "Files over 100 MB in your everyday folders"
                ),
            trailing: space.tab == .large ? AnyView(rescanButton) : nil,
            note: AnyView(modeNote),
            tabs: AnyView(PageTabs($space.tab))
        ) {
            switch space.tab {
            case .map:
                breadcrumb.rises(0)
                mapOverview.rises(1)
                rankedEntries.rises(2)
                snapshotFootnote.rises(3)
            case .large:
                largeList.rises(0)
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

    /// The page's one page-scoped control. The tab picker used to share this
    /// slot with it, which is exactly the mixture the standard forbids: two
    /// controls of different heights, one of them navigation.
    private var rescanButton: some View {
        Button {
            Task { await space.scanLarge() }
        } label: {
            if space.isScanningLarge {
                Label(t("正在查找", "Looking"), systemImage: "arrow.clockwise")
            } else {
                Label(t("重新查找", "Look again"), systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(ActionButtonStyle(.neutral))
        .actionEnabled(!space.isScanningLarge)
    }

    /// How to operate what is below, said once, above it.
    ///
    /// The map's instruction used to sit at the *bottom* of the page, past a
    /// treemap and twelve ranked cards — after the point where it could have
    /// helped anyone.
    @ViewBuilder
    private var modeNote: some View {
        switch space.tab {
        case .map:
            PageNote(
                symbol: "hand.tap",
                t(
                    "单击进入文件夹，右键可以在访达中显示或移到废纸篓。",
                    "Click a tile to open it; right-click to reveal in Finder or move to Trash."
                )
            )
        case .large:
            PageNote(
                symbol: "doc.badge.clock",
                space.isScanningLarge
                    ? t(
                        "正在翻看常用文件夹… 已看过 \(space.largeFilesScanned) 个文件",
                        "Looking through your everyday folders… \(space.largeFilesScanned) files so far"
                      )
                    : t(
                        "按大小排列。每项都显示完整路径，并可先在访达中确认。",
                        "Largest first. Every row shows its full path and opens in Finder for verification."
                      )
            )
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

    private var breadcrumb: some View {
        HStack(spacing: Space.xs) {
            ForEach(Array(space.trail.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .glyph(.badge, weight: .semibold)
                        .foregroundStyle(Palette.inkFaint)
                }
                Button {
                    Task { await space.goTo(index: index) }
                } label: {
                    Text(entry.name)
                        .font(Typo.label)
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
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                }
            } else {
                IconButton(
                    "arrow.clockwise",
                    tint: Palette.inkTertiary,
                    help: t("重新测量这一层", "Measure this level again")
                ) {
                    Task { await space.refresh() }
                }

                Reading(bytes: space.totalSize, emphasis: .dense, tint: Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.textBar)
        .glassPanel(radius: Radius.row)
    }

    // MARK: - Treemap

    /// Why the folder sizes do not add up to the used space.
    ///
    /// Only shown when there is something to explain. A Mac with no local
    /// snapshots gets no paragraph about snapshots.
    @ViewBuilder
    private var snapshotFootnote: some View {
        let count = model.storage.localSnapshots
        if count > 0 {
            PageNote(
                symbol: "clock.arrow.circlepath",
                t(
                    "这台 Mac 上有 \(count) 个 Time Machine 本地快照。快照会占住已删除或已改写文件的磁盘块，这些块不属于任何文件夹，所以上面的统计里找不到它们。可用空间那个数字已经把它们算作可回收，macOS 需要空间时会自动清除。",
                    "This Mac is holding \(count) Time Machine local snapshots. A snapshot pins the disk blocks of files you have since deleted or rewritten; those blocks belong to no folder any more, so nothing above can account for them. The free-space figure already treats them as reclaimable — macOS evicts them when it needs the room."
                )
            )
        }
    }

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
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            }

            Spacer(minLength: Space.md)

            if let item = hoveredMapItem {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.name)
                        .font(Typo.label)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(Bytes.format(item.size)) · \(mapShare(item.size))")
                        .font(Typo.captionNumeric)
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
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(color)
                        .frame(width: 9, height: 9)
                }
            }
            Text(label)
                .font(Typo.overline)
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
            let pointed = pointedItem(in: visible, rects: rects)
            // The Top 12 cards below the map share this highlight, so pointing
            // at a card lights its tile up here. The pointer's own answer wins
            // whenever it has one.
            let highlighted = pointed ?? (hoverSource == .list ? hovered : nil)

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
                        tile(item: item, rect: rect, rank: index, isHovered: highlighted == item.id)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
            }
            // Tile offsets are coordinates in the map, so their parent must
            // share the same top-leading origin. A centred frame shifts the
            // entire treemap by half the leftover width — the source of the
            // old blank left half and right-edge overflow.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            // Hover is tracked on the sized, filled container rather than on
            // the stack of tiles: a `ZStack` is only hit-testable where its
            // children are, and the tiles are `.offset` into place, so the
            // gaps between them — and the map's own margins — would report
            // nothing. `.local` is then exactly the space the tile rects were
            // laid out in, so a reported location can be tested against them
            // directly.
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    let snapped = CGPoint(x: location.x.rounded(), y: location.y.rounded())
                    if snapped != mapPointer { mapPointer = snapped }
                case .ended:
                    mapPointer = nil
                }
            }
            // Publishing the derived answer is what keeps the header readout
            // and the tile under the cursor from ever disagreeing: they are
            // now the same value, not two things updated separately.
            .onChange(of: pointed, initial: true) { _, id in
                if let id {
                    hovered = id
                    hoverSource = .map
                } else if hoverSource == .map {
                    clearHover()
                }
            }
            .animation(.smooth(duration: 0.45), value: space.entries)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.treemap)
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
    }

    private func clearHover() {
        hovered = nil
        hoverSource = nil
    }

    /// The item under the pointer, decided by position rather than by
    /// whichever tile last received a hover event. Tiles are laid out
    /// largest-first and never overlap, so the first rectangle containing the
    /// point is the answer.
    private func pointedItem(in items: [DiskMapItem], rects: [CGRect]) -> String? {
        guard let mapPointer else { return nil }
        guard let index = rects.firstIndex(where: { $0.contains(mapPointer) }),
              index < items.count
        else { return nil }
        return items[index].id
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
                SkeletonBlock()
                    .padding(2)
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
                .font(Typo.labelPlain)
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
                .glyph(.feature)
                .foregroundStyle(Palette.inkTertiary)
            Text(t("这里读不到内容", "Nothing readable here"))
                .font(Typo.cardTitle)
                .foregroundStyle(Palette.ink)
            Text(
                t(
                    "文件夹可能是空的，也可能需要「完全磁盘访问权限」才能读取。",
                    "The folder may be empty, or it may need Full Disk Access to read."
                )
            )
            .font(Typo.labelPlain)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            HStack(spacing: Space.md) {
                Button(t("打开权限设置", "Open permission settings")) {
                    model.permissions.openSettings()
                }
                .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))
                Button(t("重试", "Try again")) {
                    Task { await space.refresh() }
                }
                .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(item: DiskMapItem, rect: CGRect, rank: Int, isHovered: Bool) -> some View {
        let showLabel = rect.width > 92 && rect.height > 50
        let prominent = rect.width > 250 && rect.height > 125

        return RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            .fill(tileColor(item: item, rank: rank).gradient)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
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
                                    .glyph(.control, weight: .semibold)
                            }
                            Text(item.name)
                        }
                            .font(prominent ? Typo.cardTitle : Typo.bodyStrong)
                            .lineLimit(2)
                        Text("\(Bytes.format(item.size)) · \(mapShare(item.size))")
                            .font(prominent ? Typo.bodyNumeric : Typo.captionNumeric)
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .padding(prominent ? Space.lg : Space.sm)
                }
            }
            .padding(2)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .scaleEffect(isHovered ? 1.012 : 1, anchor: .center)
            .animation(.smooth(duration: 0.2), value: isHovered)
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
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 320), spacing: Space.md)],
                spacing: Space.sm
            ) {
                if space.entries.isEmpty && space.isScanning {
                    ForEach(0..<6, id: \.self) { _ in
                        // The placeholder is the row's own height. It used to
                        // be 76 against a 65pt card, so the page jumped the
                        // moment real data arrived.
                        SkeletonBlock(radius: Radius.card).frame(height: Layout.standardRow)
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
        HStack(spacing: Space.md) {
            // The rank sits in the column a checkbox would occupy, so these
            // cards share their title edge with every other list in the app.
            Text("\(rank)")
                .font(Typo.tag)
                .monospacedDigit()
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 16, height: 16)
                .background { Circle().fill(Palette.wellFill) }

            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .glyph(.row)
                .foregroundStyle(entry.isDirectory ? Palette.aqua : Palette.caution)
                .frame(width: Layout.rowIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(Typo.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                CapacityBar(
                    fraction: space.totalSize > 0 ? Double(entry.size) / Double(space.totalSize) : 0,
                    tint: entry.isDirectory ? Palette.aqua : Palette.caution
                )
                .frame(maxWidth: 120)
            }

            Spacer(minLength: Space.sm)

            VStack(alignment: .trailing, spacing: 1) {
                Reading(bytes: entry.size)
                Text(mapShare(entry.size))
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
            .frame(width: Layout.valueColumn, alignment: .trailing)

            IconButton("folder", help: t("在访达中显示", "Show in Finder")) {
                Removal.revealInFinder(entry.url)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.standardRow)
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

    private var largeList: some View {
        // Lazy on purpose: up to 120 rows land in one update when the scan
        // finishes, and building them all at once (each with a glass pane
        // and an icon) stalled the main thread visibly.
        LazyVStack(alignment: .leading, spacing: Space.sm) {
            if space.isScanningLarge && space.largeFiles.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBlock(radius: Radius.card).frame(height: Layout.tallRow)
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
            RowLeadingSpacer()
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "doc.fill")
                        .glyph(.row)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(width: Layout.rowIcon, height: Layout.rowIcon)
            .task(id: file.id) {
                let path = file.url.path
                icon = await Task.detached(priority: .utility) {
                    let image = NSWorkspace.shared.icon(forFile: path)
                    image.size = NSSize(width: 60, height: 60)
                    return image
                }.value
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.sm) {
                    Text(file.name)
                        .font(Typo.bodyStrong)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Badge(file.folder)
                    Text(RelativeTime.describe(file.modified))
                        .font(Typo.caption)
                        .foregroundStyle(isStale ? Palette.caution : Palette.inkTertiary)
                }

                Text(verbatim: file.url.path)
                    .font(Typo.microMono)
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(file.url.path)
            }

            Spacer(minLength: Space.md)

            Reading(bytes: file.size)
                .frame(width: Layout.valueColumn, alignment: .trailing)

            HStack(spacing: Space.xs) {
                IconButton("folder", help: t("在访达中显示 \(file.name)", "Show \(file.name) in Finder")) {
                    Removal.revealInFinder(file.url)
                }
                if canTrash {
                    // Always visible, and neutral rather than red. It moves a
                    // file to the Trash, which is recoverable — painting that
                    // red is how the app ran out of vocabulary for the things
                    // that genuinely cannot be undone. Hiding it behind hover
                    // was the other half: the page's main verb was invisible
                    // until you happened to sweep across a row.
                    Button(t("移到废纸篓", "Move to Trash"), action: onTrash)
                        .buttonStyle(ActionButtonStyle(.reversible, height: Control.compact))
                }
            }
            .frame(width: Layout.actionColumn + Control.compact, alignment: .trailing)
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.standardRow)
        .glassPanel(radius: Radius.card)
        .rowSelection(false, hovering: hovering)
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
