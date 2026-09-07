import SwiftUI
import AppKit

struct CleanView: View {
    @Environment(AppModel.self) private var model

    /// Raised when the selection is about to be erased rather than trashed.
    /// An irreversible operation gets a surface of its own to be confirmed on,
    /// which is also the only place its button is allowed to be filled.
    @State private var confirmingErase = false

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
        .animation(Motion.reveal, value: clean.isCleaning)
        .task {
            await clean.scanIfNeeded(registry: model.registry)
        }
        .sheet(isPresented: $confirmingErase) {
            EraseConfirmation(
                size: clean.selectedSize,
                count: clean.selectedCount,
                onCancel: { confirmingErase = false },
                onConfirm: {
                    confirmingErase = false
                    Task { await clean.clean(storage: model.storage, ledger: model.ledger) }
                }
            )
        }
    }

    // MARK: - Chrome

    private var rescanButton: some View {
        Button {
            Task { await clean.scan(registry: model.registry) }
        } label: {
            Label(t("重新扫描", "Rescan"), systemImage: "arrow.clockwise")
        }
        .buttonStyle(ActionButtonStyle(.neutral))
        .actionEnabled(!clean.isBusy)
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
                            // The unit sits on the number's baseline, a step
                            // down and a shade back: "79.9 GB" is a quantity
                            // and a ruler, not one word.
                            Text(parts.unit)
                                .font(Typo.cardTitle)
                                .foregroundStyle(Palette.inkTertiary)
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
        .animation(Motion.reveal, value: clean.selectedSize)
    }

    /// The page's one hero action — and the one place in the app where a
    /// single button changes intent with the state of a switch.
    ///
    /// With "Skip the Trash" off it is `go`: filled aqua, because everything
    /// it moves can be put back. Turn the switch on and the same click stops
    /// being recoverable, so the button stops looking recoverable too: it
    /// drops to `emphasis`, becomes an outlined destructive proposal, renames
    /// itself, and routes through a confirmation sheet instead of acting.
    @ViewBuilder
    private var cleanButton: some View {
        if clean.permanentDelete {
            Button {
                confirmingErase = true
            } label: {
                Label(
                    t("永久删除 \(Bytes.format(clean.selectedSize))", "Erase \(Bytes.format(clean.selectedSize))"),
                    systemImage: "trash.slash"
                )
            }
            .buttonStyle(ActionButtonStyle(.destructive, height: Control.emphasis))
            .actionEnabled(clean.selectedCount > 0 && !clean.isBusy)
        } else {
            Button {
                Task { await clean.clean(storage: model.storage, ledger: model.ledger) }
            } label: {
                Label(
                    t("移到废纸篓 \(Bytes.format(clean.selectedSize))", "Move \(Bytes.format(clean.selectedSize)) to Trash"),
                    systemImage: "trash"
                )
            }
            .buttonStyle(ActionButtonStyle(.go, height: Control.hero))
            .actionEnabled(clean.selectedCount > 0 && !clean.isBusy)
        }
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
            withAnimation(Motion.state) { action() }
        }
        .buttonStyle(TextButtonStyle())
        .disabled(clean.isBusy)
    }

    private var reassurance: some View {
        HStack(spacing: Space.md) {
            Image(systemName: clean.selectionIncludesPermanent ? "exclamationmark.triangle.fill" : "arrow.uturn.backward.circle.fill")
                .glyph(.control)
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

            ChoiceToggle(
                t("跳过废纸篓", "Skip the Trash"),
                isOn: Binding(
                    get: { clean.permanentDelete },
                    set: { clean.permanentDelete = $0 }
                ),
                tint: Palette.danger
            )
            .disabled(clean.isBusy)
        }
    }

    // MARK: - Blocked apps

    @ViewBuilder
    private var blockedBanner: some View {
        if !clean.blockedApps.isEmpty {
            GlassCard(padding: Space.md, radius: Radius.card, tint: Palette.caution) {
                HStack(spacing: Space.md) {
                    IconTile("pause.circle.fill", style: .tinted(Palette.caution))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            t(
                                "退出这些应用后还能再清理 \(Bytes.format(clean.blockedBytes))",
                                "Quit these apps to reclaim another \(Bytes.format(clean.blockedBytes))"
                            )
                        )
                        .font(Typo.bodyStrong)
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
        LazyVStack(spacing: Space.sm) {
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
                    IconTile(category.symbol, style: .tinted(category.safety.tint))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Space.sm) {
                            Text(category.title)
                                .font(Typo.subhead)
                                .foregroundStyle(Palette.ink)
                            Badge(category.safety)
                            if category.safety == .safe, category.flaggedCount > 0 {
                                Badge(
                                    t(
                                        "\(category.flaggedCount) 项需留意",
                                        "\(category.flaggedCount) need a look"
                                    ),
                                    style: .tinted(Palette.caution)
                                )
                            }
                        }
                        Text(category.consequence)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Space.md)

                    VStack(alignment: .trailing, spacing: 2) {
                        Reading(
                            bytes: category.selectedSize,
                            emphasis: .heading,
                            tint: category.selectedSize > 0 ? Palette.ink : Palette.inkTertiary
                        )
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
                        .glyph(.caption, weight: .semibold)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(width: Control.compact)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .frame(height: Layout.groupRow)
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
                        Badge(item.safety, size: .compact)
                    }
                }
                Text(verbatim: statusText ?? item.path)
                    .font(statusText == nil ? Typo.microMono : Typo.caption)
                    .foregroundStyle(statusText == nil ? Palette.inkFaint : Palette.caution)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(item.path)
            }

            Spacer(minLength: Space.sm)

            IconButton("folder", help: t("在访达中显示 \(item.title)", "Show \(item.title) in Finder"), action: revealInFinder)

            Reading(bytes: item.size, emphasis: .dense, tint: Palette.inkSecondary)
                .frame(width: Layout.valueColumn, alignment: .trailing)
        }
        .padding(.horizontal, Space.md)
        .frame(height: Layout.compactRow)
        .background {
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(Palette.aqua.opacity(isHovering ? 0.06 : 0))
                .padding(.horizontal, Space.sm)
        }
        .onHover { isHovering = $0 }
        .animation(Motion.hover, value: isHovering)
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
                .glyph(.control)
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
                        .glyph(.card)
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
                CapacityBar(fraction: model.progress?.fraction ?? 0, weight: .thick)
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
                    .font(Typo.subhead)
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
                                    .glyph(.caption, weight: .medium)
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
                        .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))
                    }
                    Button(t("好的", "Done"), action: onDismiss)
                        .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))
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
                    .font(Typo.metric)
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

// MARK: - Erase confirmation

/// The one screen in the app where an irreversible operation is confirmed, and
/// therefore the one place a filled danger button exists.
///
/// "Skip the Trash" used to turn the page's biggest button into an
/// unrecoverable delete in place, with no further ceremony: the same click, in
/// the same spot, with a different outcome. Everything irreversible now costs
/// a deliberate second step, and the sheet says plainly what will not be
/// recoverable afterwards.
private struct EraseConfirmation: View {
    let size: Int64
    let count: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.md) {
                IconTile("trash.slash", box: .large, style: .tinted(Palette.danger))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("永久删除这 \(count) 项？", "Erase these \(count) items?"))
                        .font(Typo.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(
                        t(
                            "\(Bytes.format(size)) 会被直接删除，不经过废纸篓。",
                            "\(Bytes.format(size)) will be removed outright, without going through the Trash."
                        )
                    )
                    .font(Typo.labelPlain)
                    .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(
                t(
                    "这一步无法撤销，也无法从废纸篓找回。想留一条后路的话，关掉「跳过废纸篓」再清理一次。",
                    "This cannot be undone and nothing can be put back afterwards. To keep a way out, turn off Skip the Trash and clean again."
                )
            )
            .font(Typo.caption)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Palette.hairline)

            HStack(spacing: Space.md) {
                Spacer()
                Button(t("取消", "Cancel"), action: onCancel)
                    .buttonStyle(ActionButtonStyle(.neutral))
                Button(t("永久删除", "Erase"), action: onConfirm)
                    .buttonStyle(ActionButtonStyle(.confirm))
            }
        }
        .padding(Space.xl)
        .frame(width: 460)
        .background { Palette.tankGradient.ignoresSafeArea() }
        .confirmationSurface()
    }
}
