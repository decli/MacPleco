import SwiftUI

struct TuneView: View {
    @Environment(AppModel.self) private var model

    private var tune: TuneModel { model.tune }

    var body: some View {
        Page(destination: .tune, trailing: AnyView(runButton)) {
            intro.rises(0)
            LazyVStack(spacing: Space.md) {
                ForEach(Array(tune.tasks.enumerated()), id: \.element.id) { index, task in
                    TaskCard(
                        task: task,
                        isSelected: tune.selected.contains(task.id),
                        isRunning: tune.runningTaskID == task.id,
                        result: tune.results[task.id],
                        onToggle: { tune.toggle(task.id) },
                        onRunAlone: { Task { await tune.run(task) } }
                    )
                    .rises(min(index + 1, 8))
                }
            }
        }
    }

    private var intro: some View {
        GlassCard(padding: Space.lg, radius: Radius.card) {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: "wrench.adjustable")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.aqua)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(t("针对具体毛病的小修小补", "Repairs for specific symptoms"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(
                        t(
                            "这些不是日常保养，遇到对应的问题再用。全部只影响你的账户，不需要管理员密码，也不会动到你的文件。",
                            "These aren't routine maintenance — reach for one when you hit the matching problem. All of them stay inside your own account, need no administrator password, and touch none of your files."
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Appears only once something is ticked. A permanently visible but
    /// disabled primary button just reads as broken chrome.
    @ViewBuilder
    private var runButton: some View {
        if tune.selectedCount > 0 {
            Button {
                Task { await tune.runSelected() }
            } label: {
                HStack(spacing: Space.sm) {
                    if tune.isRunning {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(t("执行 \(tune.selectedCount) 项", "Run \(tune.selectedCount)"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(tune.isRunning)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

private struct TaskCard: View {
    let task: TuneTask
    let isSelected: Bool
    let isRunning: Bool
    let result: TuneResult?
    let onToggle: () -> Void
    let onRunAlone: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            TriStateBox(state: isSelected ? .on : .off, action: onToggle)
                .padding(.top, 2)

            Image(systemName: task.symbol)
                .font(.system(size: 15))
                .foregroundStyle(Palette.aqua)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let warning = task.warning {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                        Text(warning)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Palette.caution)
                }

                if let result {
                    HStack(spacing: Space.xs) {
                        Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text(result.message)
                            .font(.system(size: 10))
                            .lineLimit(2)
                    }
                    .foregroundStyle(result.succeeded ? Palette.positive : Palette.danger)
                }
            }

            Spacer(minLength: Space.sm)

            if isRunning {
                ProgressView().controlSize(.small)
            } else if isHovering {
                Button(t("只跑这一项", "Run this one"), action: onRunAlone)
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(Space.lg)
        .glassPanel(radius: Radius.panel)
        .onHover { isHovering = $0 }
    }
}
