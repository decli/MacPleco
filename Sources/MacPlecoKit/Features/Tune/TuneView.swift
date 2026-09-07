import SwiftUI

struct TuneView: View {
    @Environment(AppModel.self) private var model

    private var tune: TuneModel { model.tune }

    var body: some View {
        Page(
            destination: .tune,
            note: AnyView(
                PageNote(
                    symbol: "lock.shield",
                    t(
                        "遇到对应的问题再用。全部只影响你的账户，不需要管理员密码，也不会动到你的文件。",
                        "Reach for one when you hit the matching problem. All of them stay inside your own account, need no administrator password, and touch none of your files."
                    )
                )
            )
        ) {
            actionBar.rises(0)
            LazyVStack(spacing: Space.sm) {
                ForEach(Array(tune.tasks.enumerated()), id: \.element.id) { index, task in
                    TaskRow(
                        task: task,
                        isSelected: tune.selected.contains(task.id),
                        isRunning: tune.runningTaskID == task.id,
                        isBusy: tune.isRunning,
                        result: tune.results[task.id],
                        onToggle: {
                            withAnimation(Motion.state) { tune.toggle(task.id) }
                        },
                        onRunAlone: { Task { await tune.run(task) } }
                    )
                    .rises(min(index + 1, 8))
                }
            }
        }
    }

    /// Always on screen.
    ///
    /// This used to appear only once something was ticked, on the theory that
    /// a disabled primary button reads as broken chrome. What it actually read
    /// as was no batch feature at all — nothing on the page said several
    /// repairs could be run together.
    private var actionBar: some View {
        SelectionBar(
            selectedCount: tune.selectedCount,
            totalCount: tune.tasks.count,
            allSelected: tune.allSelected,
            onToggleAll: {
                withAnimation(Motion.state) { tune.toggleSelectAll() }
            }
        ) {
            if !tune.results.isEmpty {
                Button(t("清除结果", "Clear results")) {
                    withAnimation(Motion.state) { tune.clearResults() }
                }
                .buttonStyle(TextButtonStyle(.quiet))
            }

            Button {
                Task { await tune.runSelected() }
            } label: {
                HStack(spacing: Space.sm) {
                    if tune.isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill").glyph(.control)
                    }
                    Text(t("执行选中项", "Run selected"))
                    if tune.selectedCount > 0 {
                        Badge.count(tune.selectedCount)
                    }
                }
            }
            // A repair is not destructive: nothing is removed, a cache is
            // rebuilt. Neutral, and outlined like every other bar action.
            .buttonStyle(ActionButtonStyle(.neutral))
            .actionEnabled(!tune.isRunning && tune.selectedCount > 0)
        }
    }
}

/// A repair, its symptom, and the one button that runs it.
///
/// Was a 22pt-radius card at two heights; now the app's standard row card, so
/// a list of repairs and a list of apps read as the same kind of list.
private struct TaskRow: View {
    let task: TuneTask
    let isSelected: Bool
    let isRunning: Bool
    let isBusy: Bool
    let result: TuneResult?
    let onToggle: () -> Void
    let onRunAlone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            TriStateBox(state: isSelected ? .on : .off, action: onToggle)

            Image(systemName: task.symbol)
                .glyph(.row)
                .foregroundStyle(isRunning ? Palette.aquaBright : Palette.aqua)
                .frame(width: Layout.rowIcon)
                .breathing(isRunning)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(Typo.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(task.detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)

                // The caveat is the one thing you need before clicking, so it
                // gets its own line and the row gets the taller of the two
                // heights — rather than the card growing by an arbitrary
                // amount and breaking the rhythm of the list.
                if let warning = task.warning {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "info.circle").glyph(.badge)
                        Text(warning).font(Typo.tag).lineLimit(1)
                    }
                    .foregroundStyle(Palette.caution)
                }
            }

            Spacer(minLength: Space.md)

            if let result {
                HStack(spacing: Space.xs) {
                    Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .glyph(.badge)
                        .symbolEffect(.bounce, value: result.message)
                    Text(result.message)
                        .font(Typo.tag)
                        .lineLimit(1)
                }
                .foregroundStyle(result.succeeded ? Palette.positive : Palette.danger)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            // Permanently visible: a repair you can only reach by discovering
            // that the row reacts to hover is a repair most people never find.
            Button(action: onRunAlone) {
                HStack(spacing: Space.xs) {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill").glyph(.control)
                    }
                    Text(isRunning ? t("执行中", "Running") : t("执行", "Run"))
                }
            }
            .buttonStyle(ActionButtonStyle(.neutral, height: Control.compact))
            .actionEnabled(!isBusy)
            .frame(width: Layout.actionColumn, alignment: .trailing)
            .help(t("只执行这一项，不影响勾选", "Run just this one; the ticks are left alone"))
        }
        .padding(.horizontal, Space.md)
        .frame(height: task.warning == nil ? Layout.standardRow : Layout.tallRow)
        .glassPanel(radius: Radius.card)
        .rowSelection(isSelected, hovering: isHovering)
        .onHover { isHovering = $0 }
        .animation(Motion.reveal, value: result?.message)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

}
