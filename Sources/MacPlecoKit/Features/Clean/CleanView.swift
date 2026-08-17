import SwiftUI
import AppKit

struct CleanView: View {
    @Environment(AppModel.self) private var model

    private var clean: CleanModel { model.clean }

    var body: some View {
        Page(destination: .clean, trailing: AnyView(rescanButton)) {
            switch clean.phase {
            case .idle, .scanning:
                ScanningCard(model: clean)
            case .ready, .cleaning:
                summary
                blockedBanner
                categoryList
            case .finished(let bytes, let trashed, let erased):
                FinishedCard(bytes: bytes, trashed: trashed, erased: erased) {
                    clean.dismissResult()
                }
                if !clean.categories.isEmpty {
                    categoryList
                }
            }
        }
        .task {
            await clean.scanIfNeeded(registry: model.registry)
        }
    }

    // MARK: - Chrome

    private var rescanButton: some View {
        Button {
            Task { await clean.scan(registry: model.registry) }
        } label: {
            Label(t("重新扫描", "Rescan"), systemImage: "arrow.clockwise")
        }
        .buttonStyle(GhostButtonStyle())
        .disabled(clean.isBusy)
    }

    // MARK: - Summary

    private var summary: some View {
        GlassCard(padding: Space.xl) {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(alignment: .top, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(t("已选择", "Selected"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.inkTertiary)
                        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                            let parts = Bytes.split(clean.selectedSize)
                            Text(parts.number)
                                .font(.system(size: 42, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                                .contentTransition(.numericText())
                            Text(parts.unit)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        Text(
                            t(
                                "共 \(clean.selectedCount) 项 · 全部可回收 \(Bytes.format(clean.totalSize))",
                                "\(clean.selectedCount) items · \(Bytes.format(clean.totalSize)) available in total"
                            )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSecondary)
                    }

                    Spacer(minLength: Space.md)

                    VStack(alignment: .trailing, spacing: Space.sm) {
                        cleanButton
                        quickSelects
                    }
                }

                Divider().overlay(Palette.hairline)

                reassurance
            }
        }
        .animation(.smooth(duration: 0.3), value: clean.selectedSize)
    }

    private var cleanButton: some View {
        Button {
            Task { await clean.clean(storage: model.storage) }
        } label: {
            HStack(spacing: Space.sm) {
                if clean.isCleaning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: clean.permanentDelete ? "trash.slash" : "trash")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(
                    clean.permanentDelete
                        ? t("永久删除 \(Bytes.format(clean.selectedSize))", "Erase \(Bytes.format(clean.selectedSize))")
                        : t("移到废纸篓 \(Bytes.format(clean.selectedSize))", "Move \(Bytes.format(clean.selectedSize)) to Trash")
                )
            }
        }
        .buttonStyle(
            PrimaryButtonStyle(tint: clean.permanentDelete ? Palette.danger : Palette.aqua)
        )
        .disabled(clean.selectedCount == 0 || clean.isBusy)
        .opacity(clean.selectedCount == 0 ? 0.5 : 1)
    }

    private var quickSelects: some View {
        HStack(spacing: Space.md) {
            quickSelect(t("推荐", "Recommended")) { clean.selectRecommended() }
            quickSelect(t("全选", "All")) { clean.selectAll() }
            quickSelect(t("清空", "None")) { clean.selectNone() }
        }
    }

    private func quickSelect(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) {
            withAnimation(.smooth(duration: 0.25)) { action() }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Palette.flow)
        .disabled(clean.isBusy)
    }

    /// The line that makes the primary button safe to press. It states the one
    /// fact a hesitant user needs, and it changes when the guarantee changes.
    private var reassurance: some View {
        HStack(spacing: Space.md) {
            Image(systemName: clean.selectionIncludesPermanent ? "exclamationmark.triangle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(clean.selectionIncludesPermanent ? Palette.caution : Palette.aqua)

            Text(
                clean.selectionIncludesPermanent
                    ? t(
                        "这次选择里包含无法恢复的内容，删除后无法找回。",
                        "This selection includes items that cannot be recovered once removed."
                      )
                    : t(
                        "所有内容会先放进废纸篓，发现删错了随时可以放回原处。",
                        "Everything goes to the Trash first, so anything removed by mistake can be put back."
                      )
            )
            .font(.system(size: 12))
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Space.sm)

            Toggle(isOn: Binding(
                get: { clean.permanentDelete },
                set: { clean.permanentDelete = $0 }
            )) {
                Text(t("跳过废纸篓", "Skip the Trash"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Palette.danger)
            .disabled(clean.isBusy)
        }
    }

    // MARK: - Blocked apps

    @ViewBuilder
    private var blockedBanner: some View {
        if !clean.blockedApps.isEmpty {
            GlassCard(padding: Space.md, radius: Radius.card, tint: Palette.caution) {
                HStack(spacing: Space.md) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.caution)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            t(
                                "退出这些应用后还能再清理 \(Bytes.format(clean.blockedBytes))",
                                "Quit these apps to reclaim another \(Bytes.format(clean.blockedBytes))"
                            )
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        Text(clean.blockedApps.prefix(6).map(\.name).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Categories

    private var categoryList: some View {
        LazyVStack(spacing: Space.md) {
            ForEach(clean.categories) { category in
                CategoryCard(
                    category: category,
                    isExpanded: clean.expanded.contains(category.id),
                    registry: model.registry,
                    onToggleSelection: { clean.toggle(category: category.id) },
                    onToggleExpanded: {
                        withAnimation(.smooth(duration: 0.28)) {
                            clean.toggleExpanded(category.id)
                        }
                    },
                    onToggleItem: { itemID in
                        clean.toggle(item: itemID, in: category.id)
                    }
                )
            }
        }
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: CleanCategory
    let isExpanded: Bool
    let registry: AppRegistry
    let onToggleSelection: () -> Void
    let onToggleExpanded: () -> Void
    let onToggleItem: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                Divider().overlay(Palette.hairline)
                itemList
            }
        }
        .glassPanel(radius: Radius.panel)
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            TriStateBox(state: boxState, tint: category.safety.tint, action: onToggleSelection)

            Button(action: onToggleExpanded) {
                HStack(spacing: Space.md) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(category.safety.tint)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: Space.sm) {
                            Text(category.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            SafetyChip(category.safety)
                        }
                        Text(category.consequence)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Space.md)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Bytes.format(category.selectedSize))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(category.selectedSize > 0 ? Palette.ink : Palette.inkTertiary)
                            .contentTransition(.numericText())
                        Text(
                            t(
                                "\(category.selectedCount)/\(category.items.count) 项 · 共 \(Bytes.format(category.totalSize))",
                                "\(category.selectedCount)/\(category.items.count) · \(Bytes.format(category.totalSize)) total"
                            )
                        )
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Space.lg)
    }

    private var boxState: TriStateBox.Mark {
        switch category.selection {
        case .none: return .off
        case .partial: return .mixed
        case .all: return .on
        }
    }

    private var itemList: some View {
        LazyVStack(spacing: 0) {
            // Long categories are truncated: nobody audits four hundred cache
            // folders one by one, and rendering them all makes the list crawl.
            ForEach(category.items.prefix(80)) { item in
                ItemRow(item: item, registry: registry) {
                    onToggleItem(item.id)
                }
            }
            if category.items.count > 80 {
                HStack {
                    Text(
                        t(
                            "另外 \(category.items.count - 80) 项较小的内容已一并计入",
                            "\(category.items.count - 80) more smaller items are included in the total"
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
                    Spacer()
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
            }
        }
        .padding(.bottom, Space.sm)
    }
}

// MARK: - Item row

private struct ItemRow: View {
    let item: CleanItem
    let registry: AppRegistry
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            TriStateBox(
                state: item.isSelected ? .on : .off,
                tint: item.safety.tint,
                action: onToggle
            )

            icon

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Space.sm) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if item.safety != .safe {
                        SafetyChip(item.safety, compact: true)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Space.sm)

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

            Text(Bytes.format(item.size))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 68, alignment: .trailing)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Palette.wellFill)
                    .padding(.horizontal, Space.sm)
            }
        }
        .onHover { isHovering = $0 }
    }

    /// Prefers the human explanation; falls back to the path only when there is
    /// nothing better to say.
    private var subtitle: String {
        if let blockedBy = item.blockedBy {
            return t("\(blockedBy) 正在运行，退出后再清理", "\(blockedBy) is running — quit it first")
        }
        if let note = item.note { return note }
        return item.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    @ViewBuilder
    private var icon: some View {
        if let bundleID = item.bundleID,
           let image = IconCache.shared.icon(forBundleID: bundleID, registry: registry) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 18, height: 18)
        }
    }
}

// MARK: - Scanning

private struct ScanningCard: View {
    let model: CleanModel

    var body: some View {
        GlassCard(padding: Space.xl) {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(spacing: Space.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.aqua)
                        .breathing(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.progress?.stage ?? t("正在检查…", "Looking around…"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(
                            t(
                                "只读取文件大小，这一步不会改动任何东西。",
                                "Only reading sizes — nothing is changed in this step."
                            )
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer()
                }
                CapacityBar(fraction: model.progress?.fraction ?? 0, height: 6)
            }
        }
    }
}

// MARK: - Result

private struct FinishedCard: View {
    let bytes: Int64
    let trashed: Int
    let erased: Int
    let onDismiss: () -> Void

    var body: some View {
        GlassCard(padding: Space.xl, tint: Palette.aqua) {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(alignment: .top, spacing: Space.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Palette.aqua)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(t("释放了 \(Bytes.format(bytes))", "Freed \(Bytes.format(bytes))"))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: Space.md) {
                    if trashed > 0 {
                        Button(t("打开废纸篓", "Open Trash")) {
                            _ = NSWorkspace.shared.open(
                                URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
                            )
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                    Button(t("好的", "Done"), action: onDismiss)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var detail: String {
        if trashed > 0 && erased > 0 {
            return t(
                "\(trashed) 项已移到废纸篓，\(erased) 项已永久删除。",
                "\(trashed) items moved to the Trash, \(erased) erased permanently."
            )
        }
        if erased > 0 {
            return t("\(erased) 项已永久删除。", "\(erased) items erased permanently.")
        }
        return t(
            "\(trashed) 项已移到废纸篓，右键选「放回原处」即可恢复。",
            "\(trashed) items moved to the Trash — right-click and choose Put Back to restore any of them."
        )
    }
}
