import SwiftUI
import AppKit

/// The always-there face of the app: a small panel behind the menu bar fish.
///
/// It answers the two questions people open a cleaner for — "how full is my
/// disk?" and "is anything worth clearing?" — and offers exactly one action for
/// each. Live CPU/memory sampling runs only while the panel is open.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private var monitor: MonitorModel { model.monitor }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            disk
            vitals
            actions
        }
        .padding(Space.lg)
        .frame(width: 316)
        // Structural lifetime, not onAppear/onDisappear: appearance callbacks
        // in a MenuBarExtra window panel have a history of firing unbalanced,
        // and one missed onDisappear would leave the sampler (and its periodic
        // /bin/ps subprocess) running forever. Task cancellation on teardown
        // is guaranteed, so the stop always runs.
        .task {
            model.storage.refresh()
            monitor.start()
            defer { monitor.stop() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
            }
        }
        .preferredColorScheme(model.appearance.scheme)
    }

    private var header: some View {
        HStack(spacing: Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.aquaSweep)
                    .frame(width: 22, height: 22)
                Image(systemName: "fish.fill")
                    .font(.system(size: Typo.Step.overline, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("MacPleco")
                .font(.system(size: Typo.Step.body, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Spacer()
            if model.ledger.totalRuns > 0 {
                Text(
                    t(
                        "已腾出 \(Bytes.format(model.ledger.totalBytes))",
                        "\(Bytes.format(model.ledger.totalBytes)) freed"
                    )
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.aqua)
            }
        }
    }

    private var disk: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("可用空间", "Free space"))
                    .font(Typo.captionStrong)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                Text(Bytes.format(model.storage.available))
                    .font(.system(size: Typo.Step.subhead, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            CapacityBar(
                fraction: model.storage.usedFraction,
                tint: model.storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua,
                height: 6
            )
            if model.clean.hasScanned, model.clean.totalSize > 0 {
                HStack(spacing: Space.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: Typo.Step.micro))
                    Text(
                        t(
                            "其中 \(Bytes.format(model.clean.totalSize)) 可以清理",
                            "\(Bytes.format(model.clean.totalSize)) of that is clearable"
                        )
                    )
                }
                .font(Typo.caption)
                .foregroundStyle(Palette.aqua)
            }
        }
        .padding(Space.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(Palette.wellFill)
        }
    }

    private var vitals: some View {
        HStack(spacing: Space.md) {
            vital(
                symbol: "cpu",
                label: t("处理器", "CPU"),
                value: "\(Int((monitor.cpuTotal * 100).rounded()))%"
            )
            vital(
                symbol: "memorychip",
                label: t("内存", "Memory"),
                value: Bytes.formatMemory(monitor.memory.used)
            )
            vital(
                symbol: "thermometer.medium",
                label: t("散热", "Thermal"),
                value: SystemInfo.thermalDescription
            )
        }
    }

    private func vital(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Space.xs) {
                Image(systemName: symbol)
                    .font(.system(size: Typo.Step.micro))
                    .foregroundStyle(Palette.aqua)
                Text(label)
                    .font(.system(size: Typo.Step.overline))
                    .foregroundStyle(Palette.inkTertiary)
            }
            Text(value)
                .font(.system(size: Typo.Step.body, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.sm + 2)
        .background {
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(Palette.wellFill)
        }
    }

    private var actions: some View {
        VStack(spacing: Space.sm) {
            Button {
                open(destination: .clean)
            } label: {
                HStack(spacing: Space.sm) {
                    Image(systemName: "sparkles")
                    Text(t("去清理", "Go clean"))
                    Spacer()
                }
            }
            .buttonStyle(PrimaryButtonStyle(wide: true))

            HStack {
                Button(t("打开 MacPleco", "Open MacPleco")) {
                    open(destination: nil)
                }
                .buttonStyle(.plain)
                .font(Typo.caption)
                .foregroundStyle(Palette.flow)

                Spacer()

                Button(t("退出", "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    private func open(destination: Destination?) {
        if let destination {
            model.destination = destination
        }
        // Focus the existing window when there is one; only ask SwiftUI for a
        // new one when the user closed it.
        let existing = NSApplication.shared.windows.first {
            $0.styleMask.contains(.titled) && !($0 is NSPanel) && $0.canBecomeMain
        }
        if existing == nil {
            openWindow(id: "main")
        }
        AppDelegate.showMainWindow()
    }
}
