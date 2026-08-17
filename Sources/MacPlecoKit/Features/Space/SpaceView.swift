import SwiftUI

struct SpaceView: View {
    @Environment(AppModel.self) private var model

    @State private var hovered: SpaceEntry?
    @State private var pendingTrash: SpaceEntry?

    private var space: SpaceModel { model.space }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            PageHeader(title: Destination.space.title, subtitle: Destination.space.subtitle) {
                if space.isScanning {
                    HStack(spacing: Space.sm) {
                        ProgressView().controlSize(.small)
                        Text("\(space.scanned)/\(space.expected)")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.xxl)

            breadcrumb
                .padding(.horizontal, Space.xxl)

            HStack(alignment: .top, spacing: Space.lg) {
                sidebar
                map
            }
            .padding(.horizontal, Space.xxl)
            .padding(.bottom, Space.xxl)
        }
        .task { await space.start() }
        .alert(item: $pendingTrash) { entry in
            Alert(
                title: Text(t("移到废纸篓？", "Move to Trash?")),
                message: Text(
                    t(
                        "「\(entry.name)」（\(Bytes.format(entry.size))）会被移到废纸篓，可以从废纸篓恢复。",
                        "“\(entry.name)” (\(Bytes.format(entry.size))) will be moved to the Trash. You can put it back from there."
                    )
                ),
                primaryButton: .destructive(Text(t("移到废纸篓", "Move to Trash"))) {
                    Task { _ = await space.trash(entry, storage: model.storage) }
                },
                secondaryButton: .cancel(Text(t("取消", "Cancel")))
            )
        }
    }

    // MARK: - Breadcrumb

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
                        .font(.system(size: 12, weight: index == space.trail.count - 1 ? .semibold : .regular))
                        .foregroundStyle(index == space.trail.count - 1 ? Palette.ink : Palette.flow)
                }
                .buttonStyle(.plain)
                .disabled(index == space.trail.count - 1)
            }

            Spacer()

            Text(
                t(
                    "当前 \(Bytes.format(space.totalSize))",
                    "\(Bytes.format(space.totalSize)) here"
                )
            )
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .glassPanel(radius: Radius.row)
    }

    // MARK: - Sidebar list

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel(t("按大小排列", "By size"))
                .padding(.horizontal, Space.sm)
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(space.entries.prefix(60)) { entry in
                        listRow(entry)
                    }
                }
            }
        }
        .frame(width: 230)
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
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Space.xs)
                Text(Bytes.format(entry.size))
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered?.id == entry.id ? Palette.wellFill : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? entry : (hovered?.id == entry.id ? nil : hovered) }
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
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                    let rect = rects[index]
                    if rect.width > 2, rect.height > 2 {
                        tile(entry: entry, rect: rect, index: index)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(minHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay {
            if space.entries.isEmpty && !space.isScanning {
                RestfulState(
                    symbol: "folder",
                    title: t("这里是空的", "Nothing here"),
                    message: t("这个文件夹里没有占用空间的内容。", "This folder isn't using any meaningful space.")
                )
            }
        }
    }

    private func tile(entry: SpaceEntry, rect: CGRect, index: Int) -> some View {
        let isHovered = hovered?.id == entry.id
        let showLabel = rect.width > 74 && rect.height > 40

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint(for: entry).gradient)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.7) : Color.black.opacity(0.18),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
            }
            .overlay(alignment: .topLeading) {
                if showLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(2)
                        Text(Bytes.format(entry.size))
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    .padding(Space.sm)
                }
            }
            .padding(1.5)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onHover { hovered = $0 ? entry : nil }
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
        if space.canTrash(entry) {
            Divider()
            Button(t("移到废纸篓…", "Move to Trash…"), role: .destructive) {
                pendingTrash = entry
            }
        }
    }

    /// Tiles are coloured by kind and depth rather than at random: folders read
    /// as the cooler end of the palette, loose files as the warmer end, so the
    /// eye can tell "one big file" from "a thousand small ones" instantly.
    private func tint(for entry: SpaceEntry) -> Color {
        let ramp: [Color] = entry.isDirectory
            ? [Palette.aquaDeep, Palette.aqua, Palette.flow]
            : [Palette.caution, Palette.danger]
        let index = abs(entry.name.hashValue) % ramp.count
        return ramp[index]
    }
}
