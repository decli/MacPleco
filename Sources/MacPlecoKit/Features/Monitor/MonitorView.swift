import SwiftUI

struct MonitorView: View {
    @Environment(AppModel.self) private var model

    private var monitor: MonitorModel { model.monitor }

    var body: some View {
        Page(destination: .monitor) {
            gauges
            processList
            footnote
        }
        .task {
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
    }

    // MARK: - Gauges

    private var gauges: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: Space.md)],
            spacing: Space.md
        ) {
            MetricCard(
                symbol: "cpu",
                label: t("处理器", "Processor"),
                value: "\(Int((monitor.cpuTotal * 100).rounded()))%",
                detail: t(
                    "应用 \(percent(monitor.cpuUser)) · 系统 \(percent(monitor.cpuSystem))",
                    "Apps \(percent(monitor.cpuUser)) · System \(percent(monitor.cpuSystem))"
                ),
                fraction: monitor.cpuTotal,
                history: monitor.cpuHistory,
                tint: monitor.cpuTotal > 0.85 ? Palette.caution : Palette.aqua
            )

            MetricCard(
                symbol: "memorychip",
                label: t("内存", "Memory"),
                value: Bytes.format(monitor.memory.used),
                detail: t(
                    "共 \(Bytes.format(monitor.memory.total)) · 已压缩 \(Bytes.format(monitor.memory.compressed))",
                    "of \(Bytes.format(monitor.memory.total)) · \(Bytes.format(monitor.memory.compressed)) compressed"
                ),
                fraction: monitor.memory.usedFraction,
                history: monitor.memoryHistory,
                tint: monitor.memory.usedFraction > 0.9 ? Palette.caution : Palette.flow
            )

            MetricCard(
                symbol: "arrow.up.arrow.down",
                label: t("网络", "Network"),
                value: "\(Bytes.format(monitor.networkIn))/s",
                detail: t(
                    "上传 \(Bytes.format(monitor.networkOut))/s",
                    "\(Bytes.format(monitor.networkOut))/s up"
                ),
                fraction: nil,
                history: monitor.networkHistory,
                tint: Palette.aquaBright
            )

            MetricCard(
                symbol: "thermometer.medium",
                label: t("散热状态", "Thermal state"),
                value: SystemInfo.thermalDescription,
                detail: t(
                    "\(SystemInfo.coreCount) 核 · 已运行 \(RelativeTime.duration(SystemInfo.uptime))",
                    "\(SystemInfo.coreCount) cores · up \(RelativeTime.duration(SystemInfo.uptime))"
                ),
                fraction: nil,
                history: [],
                tint: SystemInfo.thermalState == .nominal ? Palette.positive : Palette.caution
            )
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - Processes

    private var processList: some View {
        GlassCard(padding: Space.lg) {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack {
                    SectionLabel(t("最占资源的进程", "Busiest processes"))
                    Spacer()
                    if monitor.isStreaming {
                        HStack(spacing: Space.xs) {
                            Circle()
                                .fill(Palette.aqua)
                                .frame(width: 5, height: 5)
                            Text(t("实时", "Live"))
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }

                if monitor.processes.isEmpty {
                    HStack(spacing: Space.sm) {
                        ProgressView().controlSize(.small)
                        Text(t("正在读取…", "Reading…"))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.vertical, Space.md)
                } else {
                    VStack(spacing: 0) {
                        ForEach(monitor.processes) { process in
                            processRow(process)
                        }
                    }
                }
            }
        }
    }

    private func processRow(_ process: ProcessSample) -> some View {
        HStack(spacing: Space.md) {
            Text(process.name)
                .font(.system(size: 12))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 58, alignment: .trailing)

            Text(Bytes.format(process.memory))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 76, alignment: .trailing)

            HStack(spacing: Space.sm) {
                CapacityBar(
                    fraction: min(1, process.cpu / 100),
                    tint: process.cpu > 60 ? Palette.caution : Palette.aqua,
                    height: 4
                )
                .frame(width: 54)
                Text(String(format: "%.1f%%", process.cpu))
                    .font(.system(size: 11, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
    }

    private var footnote: some View {
        Text(
            t(
                "风扇转速和芯片温度需要系统底层权限才能读取，MacPleco 不去猜这些数字，所以只显示 macOS 自己公开的散热状态。",
                "Fan speed and die temperature need privileged access to read. MacPleco won't guess at numbers, so it shows the thermal state macOS publishes instead."
            )
        )
        .font(.system(size: 11))
        .foregroundStyle(Palette.inkTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Metric card

private struct MetricCard: View {
    let symbol: String
    let label: String
    let value: String
    let detail: String
    let fraction: Double?
    let history: [Double]
    let tint: Color

    var body: some View {
        GlassCard(padding: Space.lg, radius: Radius.card) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Sparkline(values: history, tint: tint)
                    .frame(height: 30)

                if let fraction {
                    CapacityBar(fraction: fraction, tint: tint, height: 4)
                }

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Sparkline

private struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            // Each series is normalised against its own peak; an absolute scale
            // would flatten network traffic into a dead line most of the time.
            let peak = max(values.max() ?? 1, 0.0001)
            let step = size.width / CGFloat(values.count - 1)

            var line = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height - CGFloat(min(1, value / peak)) * size.height
                if index == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                }
            }

            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()

            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.32), tint.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(tint), lineWidth: 1.5)
        }
    }
}
