import SwiftUI
import AppKit

struct CleanView: View {
    @Environment(AppModel.self) private var model

    private var clean: CleanModel { model.clean }

    var body: some View {
        ZStack {
            Page(destination: .clean, trailing: AnyView(rescanButton)) {
                switch clean.phase {
                case .idle, .scanning:
                    ScanningCard(model: clean).rises(0)
                case .ready, .cleaning:
                    summary.rises(0)
                    blockedBanner.rises(1)
                    categoryList
                case .finished(let bytes, let trashed, let erased):
                    FinishedCard(
                        bytes: bytes,
                        trashed: trashed,
                        erased: erased,
                        skipped: clean.lastSkipped
                    ) {
                        clean.dismissResult()
                    }
                    .rises(0)
                    if !clean.categories.isEmpty {
                        categoryList
                    }
                }
            }

            if clean.isCleaning {
                CleaningVeil()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.35), value: clean.isCleaning)
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
                            .font(Typo.label)
                            .foregroundStyle(Palette.inkTertiary)
                        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                            let parts = Bytes.split(clean.selectedSize)
                            Text(parts.number)
                                .font(Typo.hero)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                                .contentTransition(.numericText())
                            Text(parts.unit)
                                .font(Typo.cardTitle)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        Text(
                            t(
                                "共 \(clean.selectedCount) 项 · 全部可回收 \(Bytes.format(clean.totalSize))",
                                "\(clean.selectedCount) items · \(Bytes.format(clean.totalSize)) available in total"
                            )
                        )
                        .font(Typo.labelPlain)
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
            Task { await clean.clean(storage: model.storage, ledger: model.ledger) }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: clean.permanentDelete ? "trash.slash" : "trash")
                    .font(.system(size: Typo.Step.body, weight: .semibold))
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
        .font(Typo.label)
        .foregroundStyle(Palette.flow)
        .disabled(clean.isBusy)
    }

    private var reassurance: some View {
        HStack(spacing: Space.md) {
            Image(systemName: clean.selectionIncludesPermanent ? "exclamationmark.triangle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: Typo.Step.body))
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
            .font(Typo.labelPlain)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Space.sm)

            Toggle(isOn: Binding(
                get: { clean.permanentDelete },
                set: { clean.permanentDelete = $0 }
            )) {
                Text(t("跳过废纸篓", "Skip the Trash"))
                    .font(Typo.caption)
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.caution.opacity(0.16))
                            .frame(width: 30, height: 30)
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: Typo.Step.subhead))
                            .foregroundStyle(Palette.caution)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            t(
                                "退出这些应用后还能再清理 \(Bytes.format(clean.blockedBytes))",
                                "Quit these apps to reclaim another \(Bytes.format(clean.blockedBytes))"
                            )
                        )
                        .font(.system(size: Typo.Step.body, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        Text(clean.blockedApps.prefix(6).map(\.name).joined(separator: " · "))
                            .font(Typo.caption)
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
            ForEach(Array(clean.categories.enumerated()), id: \.element.id) { index, category in
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
                .rises(min(index + 2, 8))
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(category.safety.tint.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: category.symbol)
                            .font(.system(size: Typo.Step.subhead))
                            .foregroundStyle(category.safety.tint)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: Space.sm) {
                            Text(category.title)
                                .font(Typo.subhead)
                                .foregroundStyle(Palette.ink)
                            SafetyChip(category.safety)
                            if category.safety == .safe, category.flaggedCount > 0 {
                                Text(
                                    t(
                                        "\(category.flaggedCount) 项需留意",
                                        "\(category.flaggedCount) need a look"
                                    )
                                )
                                .font(.system(size: Typo.Step.overline))
                                .foregroundStyle(Palette.caution)
                            }
                        }
                        Text(category.consequence)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Space.md)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Bytes.format(category.selectedSize))
                            .font(.system(size: Typo.Step.subhead, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(category.selectedSize > 0 ? Palette.ink : Palette.inkTertiary)
                            .contentTransition(.numericText())
                        Text(
                            t(
                                "\(category.selectedCount)/\(category.items.count) 项 · 共 \(Bytes.format(category.totalSize))",
                                "\(category.selectedCount)/\(category.items.count) · \(Bytes.format(category.totalSize)) total"
                            )
                        )
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: Typo.Step.caption, weight: .semibold))
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
            // Every item included in a cleanup must remain inspectable. The
            // lazy stack creates rows as they approach the viewport, so there
            // is no need to hide the tail of a large category for performance.
            ForEach(category.items) { item in
                ItemRow(item: item, registry: registry) {
                    onToggleItem(item.id)
                }
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
                        .font(Typo.label)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if item.safety != .safe {
                        SafetyChip(item.safety, compact: true)
                    }
                }
                if let statusText {
                    Text(statusText)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }
                Text(verbatim: item.path)
                    .font(Typo.microMono)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(item.path)
            }

            Spacer(minLength: Space.sm)

            Button(action: revealInFinder) {
                Label(t("访达", "Finder"), systemImage: "folder")
                    .font(Typo.captionStrong)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(Palette.flow)
            .help(t("在访达中显示", "Show in Finder"))
            .accessibilityLabel(t("在访达中显示 \(item.title)", "Show \(item.title) in Finder"))

            Text(Bytes.format(item.size))
                .font(.system(size: Typo.Step.label, weight: .medium, design: .rounded))
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
        .contextMenu {
            Button(action: revealInFinder) {
                Label(t("在访达中显示", "Show in Finder"), systemImage: "folder")
            }
            Button(action: copyFullPath) {
                Label(t("复制完整路径", "Copy Full Path"), systemImage: "doc.on.doc")
            }
        }
    }

    private var statusText: String? {
        if let blockedBy = item.blockedBy {
            return t("\(blockedBy) 正在运行，退出后再清理", "\(blockedBy) is running — quit it first")
        }
        if let note = item.note { return note }
        return nil
    }

    private func revealInFinder() {
        Removal.revealInFinder(item.url)
    }

    private func copyFullPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
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
                .font(.system(size: Typo.Step.label))
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
                        .font(.system(size: Typo.Step.cardTitle))
                        .foregroundStyle(Palette.aqua)
                        .breathing(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.progress?.stage ?? t("正在检查…", "Looking around…"))
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.ink)
                        Text(
                            t(
                                "只读取文件大小，这一步不会改动任何东西。",
                                "Only reading sizes — nothing is changed in this step."
                            )
                        )
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer()
                }
                CapacityBar(fraction: model.progress?.fraction ?? 0, height: 6)
            }
        }
    }
}

// MARK: - Cleaning veil

/// The full-page moment while files travel to the Trash. Honest about what it
/// knows: the system reports one completion for the whole batch, so this shows
/// life — rising bubbles — rather than a fabricated per-file ticker.
private struct CleaningVeil: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Space.lg) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        for index in 0..<22 {
                            let seed = Double(index) * 131.7
                            let speed = 0.16 + 0.08 * Double(index % 4)
                            let progress = (time * speed + seed).truncatingRemainder(dividingBy: 1)
                            let sway = sin(time * 1.4 + seed) * 9
                            let x = size.width * (0.15 + 0.7 * ((seed / 7.3).truncatingRemainder(dividingBy: 1))) + sway
                            let y = size.height * (1 - progress)
                            let radius = 2.0 + Double(index % 4)
                            let fade = min(1, min(progress / 0.15, (1 - progress) / 0.2))
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                with: .color(Palette.aqua.opacity(0.5 * fade))
                            )
                        }
                    }
                    .frame(width: 180, height: 150)
                }

                Text(t("正在把选中的内容移入废纸篓…", "Moving the selection to the Trash…"))
                    .font(.system(size: Typo.Step.subhead, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(t("马上就好，不用盯着。", "Almost there — no need to watch."))
                    .font(Typo.labelPlain)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(Space.xxl)
            .glassPanel(radius: Radius.panel)
        }
    }
}

// MARK: - Result

/// The payoff frame: the freed number counts up under a ring that draws itself
/// closed, with one brief particle burst. This is the screenshot moment.
private struct FinishedCard: View {
    let bytes: Int64
    let trashed: Int
    let erased: Int
    /// Apps that started up between the scan and the click. Their caches were
    /// left alone, and saying so is the difference between a number that is
    /// low and a number that is wrong.
    let skipped: [BlockedApp]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var settled = false

    private let duration: Double = 1.1

    var body: some View {
        GlassCard(padding: Space.xl, tint: Palette.aqua) {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(spacing: Space.xl) {
                    celebration
                    VStack(alignment: .leading, spacing: Space.xs) {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: settled || reduceMotion)) { timeline in
                            let elapsed = timeline.date.timeIntervalSince(start)
                            let eased = reduceMotion ? 1 : min(1, 1 - pow(1 - min(1, elapsed / duration), 3))
                            let shown = Int64(Double(bytes) * eased)
                            Text(t("释放了 \(Bytes.format(shown))", "Freed \(Bytes.format(shown))"))
                                .font(Typo.metric)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                        }
                        Text(detail)
                            .font(Typo.labelPlain)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !skipped.isEmpty {
                            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: Typo.Step.caption, weight: .medium))
                                    .foregroundStyle(Palette.caution)
                                    .frame(width: 13, height: 13)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                                Text(skippedDetail)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, Space.xs)
                        }
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
        .task {
            start = Date()
            try? await Task.sleep(for: .seconds(duration + 0.5))
            settled = true
        }
    }

    private var celebration: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: settled || reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let ringProgress = reduceMotion ? 1 : min(1, elapsed / 0.7)

            ZStack {
                Circle()
                    .stroke(Palette.aqua.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Palette.aquaSweep,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: Typo.Step.metric, weight: .bold))
                    .foregroundStyle(Palette.aqua)
                    .scaleEffect(ringProgress >= 1 ? 1 : 0.4 + 0.6 * ringProgress)
                    .opacity(ringProgress)

                // One brief burst as the ring closes.
                if !reduceMotion, elapsed > 0.55, elapsed < 1.2 {
                    let burst = (elapsed - 0.55) / 0.65
                    ForEach(0..<12, id: \.self) { index in
                        Circle()
                            .fill(index.isMultiple(of: 3) ? Palette.flow : Palette.aquaBright)
                            .frame(width: 4, height: 4)
                            .offset(y: -(26 + burst * 30))
                            .rotationEffect(.degrees(Double(index) / 12 * 360))
                            .opacity(1 - burst)
                    }
                }
            }
            .frame(width: 64, height: 64)
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

    private var skippedDetail: String {
        let names = skipped.map(\.name).joined(separator: "、")
        let namesEN = skipped.map(\.name).joined(separator: ", ")
        let bytes = Bytes.format(skipped.reduce(0) { $0 + $1.bytes })
        return t(
            "跳过了 \(names)：扫描之后它启动了，\(bytes) 留在原处。退出它再清理一次即可。",
            "Skipped \(namesEN): it started up after the scan, so \(bytes) was left in place. Quit it and clean again."
        )
    }
}
