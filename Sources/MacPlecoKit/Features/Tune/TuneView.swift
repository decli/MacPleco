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
            LazyVStack(spacing: Space.md) {
                ForEach(Array(tune.tasks.enumerated()), id: \.element.id) { index, task in
                    TaskCard(
                        task: task,
                        isSelected: tune.selected.contains(task.id),
                        isRunning: tune.runningTaskID == task.id,
                        isBusy: tune.isRunning,
                        result: tune.results[task.id],
                        onToggle: {
                            withAnimation(.smooth(duration: 0.2)) { tune.toggle(task.id) }
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
                withAnimation(.smooth(duration: 0.25)) { tune.toggleSelectAll() }
            }
        ) {
            if !tune.results.isEmpty {
                Button(t("清除结果", "Clear results")) {
                    withAnimation(.smooth(duration: 0.25)) { tune.clearResults() }
                }
                .buttonStyle(.plain)
                .font(Typo.labelPlain)
                .foregroundStyle(Palette.inkTertiary)
            }

            Button {
                Task { await tune.runSelected() }
            } label: {
                HStack(spacing: Space.sm) {
                    if tune.isRunning {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(t("执行选中项", "Run selected"))
                    if tune.selectedCount > 0 {
                        CountPill(tune.selectedCount)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(tune.isRunning || tune.selectedCount == 0)
            .opacity(tune.selectedCount == 0 ? 0.45 : 1)
        }
    }
}

private struct TaskCard: View {
    let task: TuneTask
    let isSelected: Bool
    let isRunning: Bool
    let isBusy: Bool
    let result: TuneResult?
    let onToggle: () -> Void
    let onRunAlone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            TriStateBox(state: isSelected ? .on : .off, action: onToggle)
                .padding(.top, 2)

            Image(systemName: task.symbol)
                .font(.system(size: Typo.Step.subhead))
                .foregroundStyle(isRunning ? Palette.aquaBright : Palette.aqua)
                .frame(width: 24)
                .padding(.top, 1)
                .breathing(isRunning)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(task.title)
                    .font(.system(size: Typo.Step.body, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                Text(task.detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let warning = task.warning {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: Typo.Step.micro))
                        Text(warning)
                            .font(.system(size: Typo.Step.overline))
                    }
                    .foregroundStyle(Palette.caution)
                }

                if let result {
                    HStack(spacing: Space.xs) {
                        Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: Typo.Step.overline))
                            .symbolEffect(.bounce, value: result.message)
                        Text(result.message)
                            .font(.system(size: Typo.Step.overline))
                            .lineLimit(2)
                    }
                    .foregroundStyle(result.succeeded ? Palette.positive : Palette.danger)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            Spacer(minLength: Space.sm)

            // Permanently visible: a repair you can only reach by discovering
            // that the row reacts to hover is a repair most people never find.
            Button(action: onRunAlone) {
                HStack(spacing: Space.xs) {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: Typo.Step.micro))
                    }
                    Text(isRunning ? t("执行中", "Running") : t("执行", "Run"))
                }
            }
            .buttonStyle(GhostButtonStyle(tint: isRunning ? Palette.inkTertiary : Palette.aqua))
            .disabled(isBusy)
            .opacity(isBusy && !isRunning ? 0.4 : 1)
            .help(t("只执行这一项，不影响勾选", "Run just this one; the ticks are left alone"))
        }
        .padding(Space.lg)
        .glassPanel(radius: Radius.panel)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .strokeBorder(Palette.aqua.opacity(isSelected ? 0.5 : 0), lineWidth: 1.5)
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .fill(Palette.aqua.opacity(isSelected ? 0.07 : (isHovering ? 0.035 : 0)))
        }
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.2), value: isSelected)
        .animation(.smooth(duration: 0.2), value: isHovering)
        .animation(.smooth(duration: 0.3), value: result?.message)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
