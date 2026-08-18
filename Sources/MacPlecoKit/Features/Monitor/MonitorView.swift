import SwiftUI
import AppKit

struct MonitorView: View {
    @Environment(AppModel.self) private var model

    private var monitor: MonitorModel { model.monitor }

    var body: some View {
        Page(destination: .monitor) {
            gauges.rises(0)
            processList.rises(1)
            footnote.rises(2)
        }
        // Same structural pairing as the menu bar panel: the deferred stop is
        // tied to task cancellation, which SwiftUI guarantees on teardown.
        .task {
            monitor.start()
            defer { monitor.stop() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    // MARK: - Gauges

    private var gauges: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 250), spacing: Space.md)],
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
                fraction: nil,
                history: monitor.cpuHistory,
                tint: monitor.cpuTotal > 0.85 ? Palette.caution : Palette.aqua
            ) {
                CoreGrid(loads: monitor.coreLoads)
            }

            MetricCard(
                symbol: "memorychip",
                label: t("内存", "Memory"),
                value: Bytes.formatMemory(monitor.memory.used),
                detail: t(
                    "共 \(Bytes.formatMemory(monitor.memory.total)) · 已压缩 \(Bytes.formatMemory(monitor.memory.compressed))",
                    "of \(Bytes.formatMemory(monitor.memory.total)) · \(Bytes.formatMemory(monitor.memory.compressed)) compressed"
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
                symbol: "macbook",
                label: t("这台 Mac", "This Mac"),
                value: SystemInfo.chip.replacingOccurrences(of: "Apple ", with: ""),
                detail: t(
                    "\(SystemInfo.coreCount) 核 · \(Bytes.formatMemory(SystemInfo.physicalMemory)) 内存 · macOS \(SystemInfo.osVersion)",
                    "\(SystemInfo.coreCount) cores · \(Bytes.formatMemory(SystemInfo.physicalMemory)) memory · macOS \(SystemInfo.osVersion)"
                ),
                fraction: nil,
                history: [],
                tint: SystemInfo.thermalState == .nominal ? Palette.positive : Palette.caution,
                badge: SystemInfo.thermalDescription
            ) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.inkTertiary)
                    Text(
                        t(
                            "已运行 \(RelativeTime.duration(SystemInfo.uptime))",
                            "Up \(RelativeTime.duration(SystemInfo.uptime))"
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Space.xs)
            }
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
            ProcessIcon(pid: process.pid)

            Text(process.name)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 58, alignment: .trailing)

            Text(Bytes.formatMemory(process.memory))
                .font(.system(size: 11.5, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 78, alignment: .trailing)

            HStack(spacing: Space.sm) {
                CapacityBar(
                    fraction: min(1, process.cpu / 100),
                    tint: process.cpu > 60 ? Palette.caution : Palette.aqua,
                    height: 4
                )
                .frame(width: 56)
                Text(String(format: "%.1f%%", process.cpu))
                    .font(.system(size: 11.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
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

// MARK: - Process icon

/// GUI processes get their real app icon; daemons get a quiet gear. Lookups go
/// through `NSRunningApplication` and are memoised per pid.
private struct ProcessIcon: View {
    let pid: Int32

    var body: some View {
        if let icon = ProcessIconCache.shared.icon(for: pid) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 10))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 18, height: 18)
        }
    }
}

@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()
    private var cache: [Int32: NSImage?] = [:]

    func icon(for pid: Int32) -> NSImage? {
        if let hit = cache[pid] { return hit }
        let image = NSRunningApplication(processIdentifier: pid)?.icon
        image?.size = NSSize(width: 36, height: 36)
        if cache.count > 400 { cache.removeAll() }
        cache[pid] = image
        return image
    }
}

// MARK: - Core grid

/// One slim bar per logical core, under the CPU sparkline. The point is shape
/// recognition — "one core pinned" versus "everything busy" — not numbers.
private struct CoreGrid: View {
    let loads: [Double]

    var body: some View {
        if loads.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(Array(loads.enumerated()), id: \.offset) { _, load in
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(load > 0.85 ? Palette.caution : Palette.aqua)
                                .frame(height: max(2, geo.size.height * load))
                        }
                    }
                }
            }
            .frame(height: 22)
            .animation(.smooth(duration: 0.5), value: loads)
            .accessibilityLabel(t("每个核心的负载", "Per-core load"))
        }
    }
}

// MARK: - Metric card

private struct MetricCard<Extra: View>: View {
    let symbol: String
    let label: String
    let value: String
    let detail: String
    let fraction: Double?
    let history: [Double]
    let tint: Color
    var badge: String?
    @ViewBuilder var extra: () -> Extra

    init(
        symbol: String,
        label: String,
        value: String,
        detail: String,
        fraction: Double?,
        history: [Double],
        tint: Color,
        badge: String? = nil,
        @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }
    ) {
        self.symbol = symbol
        self.label = label
        self.value = value
        self.detail = detail
        self.fraction = fraction
        self.history = history
        self.tint = tint
        self.badge = badge
        self.extra = extra
    }

    var body: some View {
        GlassCard(padding: Space.lg, radius: Radius.card, lifts: true) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: symbol)
                        .font(.system(size: 11.5))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 2.5)
                            .background { Capsule().fill(tint.opacity(0.14)) }
                    }
                }

                Text(value)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if !history.isEmpty {
                    Sparkline(values: history, tint: tint)
                        .frame(height: 30)
                }

                extra()

                if let fraction {
                    CapacityBar(fraction: fraction, tint: tint, height: 4)
                }

                Text(detail)
                    .font(.system(size: 10.5))
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
