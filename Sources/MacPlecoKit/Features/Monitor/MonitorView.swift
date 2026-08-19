import SwiftUI
import AppKit

struct MonitorView: View {
    @Environment(AppModel.self) private var model

    @State private var pendingEnd: ProcessSample?

    private var monitor: MonitorModel { model.monitor }

    var body: some View {
        Page(destination: .monitor) {
            gauges.rises(0)
            machineStrip.rises(1)
            processList.rises(2)
            footnote.rises(3)
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
        .alert(
            t("结束这个进程？", "End this process?"),
            isPresented: Binding(
                get: { pendingEnd != nil },
                set: { if !$0 { pendingEnd = nil } }
            ),
            presenting: pendingEnd
        ) { process in
            Button(t("请求退出", "Ask to quit")) {
                Task { await monitor.end(process, force: false) }
                pendingEnd = nil
            }
            Button(t("强制结束", "Force quit"), role: .destructive) {
                Task { await monitor.end(process, force: true) }
                pendingEnd = nil
            }
            Button(t("取消", "Cancel"), role: .cancel) { pendingEnd = nil }
        } message: { process in
            Text(
                t(
                    "「\(process.name)」（PID \(process.pid)）。请求退出会让它有机会先保存；强制结束会立刻终止，未保存的内容会丢失。",
                    "“\(process.name)” (PID \(process.pid)). Asking gives it a chance to save first; forcing ends it immediately and unsaved work is lost."
                )
            )
        }
    }

    // MARK: - Gauges

    /// Four live vitals, all built from the same card so the row is one height.
    /// Each carries a legend, because every one of them is really two or three
    /// quantities and a single colour cannot say which is which.
    ///
    /// The legend slot is 30pt rather than the 13pt one line needs: at four
    /// columns the memory card's three entries only keep their labels over two
    /// lines, and the slot is declared per card, so every card reserves the
    /// room the widest legend can ask for. That is what keeps the row one
    /// height — see `LegendRow`.
    private var gauges: some View {
        StatCardGrid(minimum: 236) {
            StatCard(
                symbol: "cpu",
                label: t("处理器", "Processor"),
                value: "\(Int((monitor.cpuTotal * 100).rounded()))%",
                detail: coreDetail,
                tint: monitor.cpuTotal > 0.85 ? Palette.caution : Palette.chartTeal,
                chartHeight: 32,
                extraHeight: 30
            ) {
                Sparkline([
                    .init(values: monitor.cpuUserHistory, color: Palette.chartTeal),
                    .init(values: monitor.cpuSystemHistory, color: Palette.chartViolet, filled: false)
                ])
            } extra: {
                LegendRow([
                    .init(Palette.chartTeal, t("应用", "Apps"), value: percent(monitor.cpuUser)),
                    .init(Palette.chartViolet, t("系统", "System"), value: percent(monitor.cpuSystem))
                ])
            }

            StatCard(
                symbol: "memorychip",
                label: t("内存", "Memory"),
                value: Bytes.formatMemory(monitor.memory.used),
                detail: t(
                    "共 \(Bytes.formatMemory(monitor.memory.total))",
                    "of \(Bytes.formatMemory(monitor.memory.total))"
                ),
                tint: monitor.memory.usedFraction > 0.9 ? Palette.caution : Palette.chartBlue,
                chartHeight: 32,
                extraHeight: 30
            ) {
                // A stacked bar rather than a plain fill: "used" is three
                // different things, and which one is growing changes what you
                // would do about it.
                VStack(spacing: Space.xs) {
                    Spacer(minLength: 0)
                    SegmentedBar(segments: memorySegments, height: 7)
                    Spacer(minLength: 0)
                }
            } extra: {
                LegendRow([
                    .init(Palette.chartBlue, t("应用", "Apps"), value: Bytes.formatMemory(appMemory)),
                    .init(
                        Palette.chartViolet,
                        t("系统占用", "Wired"),
                        value: Bytes.formatMemory(monitor.memory.wired)
                    ),
                    .init(
                        Palette.chartAmber,
                        t("压缩", "Compressed"),
                        value: Bytes.formatMemory(monitor.memory.compressed)
                    )
                ])
            }

            StatCard(
                symbol: "cube.transparent",
                label: "GPU",
                value: monitor.gpu.device.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                detail: gpuDetail,
                tint: Palette.chartViolet,
                progress: monitor.gpu.device,
                chartHeight: 32,
                extraHeight: 30
            ) {
                Sparkline(values: monitor.gpuHistory, tint: Palette.chartViolet)
            } extra: {
                if monitor.gpu.isAvailable {
                    LegendRow([
                        .init(
                            Palette.chartViolet,
                            t("渲染", "Renderer"),
                            value: percent(monitor.gpu.renderer ?? 0)
                        ),
                        .init(
                            Palette.chartTeal,
                            t("分块", "Tiler"),
                            value: percent(monitor.gpu.tiler ?? 0)
                        )
                    ])
                }
            }

            StatCard(
                symbol: "arrow.up.arrow.down",
                label: t("网络", "Network"),
                value: "\(Bytes.format(monitor.networkIn))/s",
                detail: networkDetail,
                tint: Palette.chartTeal,
                chartHeight: 32,
                extraHeight: 30
            ) {
                Sparkline([
                    .init(values: monitor.networkInHistory, color: Palette.chartTeal),
                    .init(values: monitor.networkOutHistory, color: Palette.chartAmber, filled: false)
                ])
            } extra: {
                LegendRow([
                    .init(
                        Palette.chartTeal,
                        t("下载", "Down"),
                        value: "\(Bytes.format(monitor.networkIn))/s"
                    ),
                    .init(
                        Palette.chartAmber,
                        t("上传", "Up"),
                        value: "\(Bytes.format(monitor.networkOut))/s"
                    )
                ])
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// "Used" memory minus the parts that get their own colour.
    private var appMemory: Int64 {
        max(0, monitor.memory.used - monitor.memory.wired - monitor.memory.compressed)
    }

    private var memorySegments: [SegmentedBar.Segment] {
        let total = max(1, monitor.memory.total)
        func share(_ value: Int64) -> Double { Double(value) / Double(total) }
        return [
            .init(id: "app", fraction: share(appMemory), color: Palette.chartBlue),
            .init(id: "wired", fraction: share(monitor.memory.wired), color: Palette.chartViolet),
            .init(id: "compressed", fraction: share(monitor.memory.compressed), color: Palette.chartAmber)
        ]
    }

    // The four gauge subtitles are all the same kind of sentence: one fact
    // about this machine or this window of samples — cores, installed memory,
    // video memory, peak rate. Two of them used to explain how their own chart
    // was drawn, which the legend directly above already says.

    private var coreDetail: String {
        let cores = SystemInfo.coreCount
        let performance = SystemInfo.performanceCoreCount
        guard performance > 0, performance < cores else {
            return t("\(cores) 个核心", "\(cores) cores")
        }
        return t(
            "\(cores) 个核心 · \(performance) 性能核",
            "\(cores) cores · \(performance) performance"
        )
    }

    private var gpuDetail: String {
        guard monitor.gpu.isAvailable else {
            return t("这台 Mac 没有报告 GPU 使用率", "This Mac reports no GPU utilisation")
        }
        guard let memory = monitor.gpu.inUseMemory, memory > 0 else {
            return t("显存占用未报告", "video memory not reported")
        }
        return t(
            "显存占用 \(Bytes.formatMemory(memory))",
            "\(Bytes.formatMemory(memory)) video memory in use"
        )
    }

    /// The highest rate in either direction across the plotted window, so the
    /// card says what the spike was after the spike has scrolled past.
    private var networkDetail: String {
        let peak = max(
            monitor.networkInHistory.max() ?? 0,
            monitor.networkOutHistory.max() ?? 0
        )
        guard peak > 0 else {
            return t("暂无流量", "no traffic yet")
        }
        return t(
            "峰值 \(Bytes.format(peak))/s",
            "peak \(Bytes.format(peak))/s"
        )
    }

    // MARK: - Machine strip

    /// Static facts about the Mac, plus the per-core bars.
    ///
    /// These used to be squeezed into the metric grid, where the extra content
    /// made two of the four cards taller than the others. As their own strip
    /// they get the width they deserve and the grid above stays even.
    private var machineStrip: some View {
        GlassCard(padding: Space.lg, radius: Radius.card) {
            HStack(alignment: .center, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "macbook")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkTertiary)
                        Text(SystemInfo.chip.replacingOccurrences(of: "Apple ", with: ""))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text(SystemInfo.thermalDescription)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(thermalTint)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 2.5)
                            .background { Capsule().fill(thermalTint.opacity(0.14)) }
                    }
                    Text(
                        t(
                            "\(SystemInfo.coreCount) 核 · \(Bytes.formatMemory(SystemInfo.physicalMemory)) 内存 · macOS \(SystemInfo.osVersion) · 已运行 \(RelativeTime.duration(SystemInfo.uptime))",
                            "\(SystemInfo.coreCount) cores · \(Bytes.formatMemory(SystemInfo.physicalMemory)) memory · macOS \(SystemInfo.osVersion) · up \(RelativeTime.duration(SystemInfo.uptime))"
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                }

                Spacer(minLength: Space.md)

                VStack(alignment: .trailing, spacing: Space.xs) {
                    Text(t("每个核心的负载", "Per-core load"))
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Palette.inkTertiary)
                    CoreGrid(loads: monitor.coreLoads)
                        .frame(width: 260, height: 26)
                }
            }
        }
    }

    private var thermalTint: Color {
        SystemInfo.thermalState == .nominal ? Palette.positive : Palette.caution
    }

    // MARK: - Processes

    private var processList: some View {
        @Bindable var monitor = model.monitor

        return GlassCard(padding: Space.lg) {
            VStack(alignment: .leading, spacing: Space.md) {
                processControls

                if let outcome = monitor.lastOutcome {
                    Label {
                        Text(outcome.message)
                    } icon: {
                        Image(systemName: outcome.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(outcome.succeeded ? Palette.positive : Palette.caution)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: outcome.message) {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation(.smooth(duration: 0.3)) { monitor.clearOutcome() }
                    }
                }

                if monitor.processes.isEmpty {
                    emptyProcessState
                } else {
                    VStack(spacing: 0) {
                        processHeader
                        Divider().overlay(Palette.hairline)
                        ForEach(monitor.processes) { process in
                            ProcessRow(
                                process: process,
                                sort: monitor.processSort,
                                onReveal: { if let url = process.revealURL { Removal.revealInFinder(url) } },
                                onEnd: { pendingEnd = process }
                            )
                        }
                    }
                    .animation(
                        monitor.processOrder == .live ? .smooth(duration: 0.42) : nil,
                        value: monitor.processes.map(\.pid)
                    )
                }
            }
            .animation(.smooth(duration: 0.3), value: monitor.lastOutcome?.message)
        }
    }

    private var processControls: some View {
        @Bindable var monitor = model.monitor

        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.md) {
                SectionLabel(t("最占资源的进程", "Busiest processes"))
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

                Spacer()

                Picker("", selection: $monitor.processOrder) {
                    ForEach(ProcessOrderMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                .help(
                    t(
                        "实时排序会随数据改变行位置；固定位置只刷新数字，进程退出时才补位。",
                        "Live order moves rows with the data; fixed positions refresh values and only fill gaps when a process exits."
                    )
                )
            }

            HStack(spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.inkTertiary)
                    TextField(
                        t("搜索进程名、路径或 PID", "Search name, path or PID"),
                        text: $monitor.query
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    if !monitor.query.isEmpty {
                        Button {
                            monitor.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .glassSurface(Capsule(style: .continuous))
                .frame(maxWidth: 300)
                .animation(.smooth(duration: 0.2), value: monitor.query.isEmpty)

                Picker("", selection: $monitor.scope) {
                    ForEach(ProcessScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                .help(
                    t(
                        "「系统」是 macOS 自己的后台进程，通常不该结束。",
                        "“System” covers macOS's own background processes, which usually should not be ended."
                    )
                )

                Spacer()

                Text(
                    t(
                        "显示 \(monitor.processes.count) / 匹配 \(monitor.matchCount)",
                        "\(monitor.processes.count) shown of \(monitor.matchCount)"
                    )
                )
                .font(.system(size: 10.5))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    @ViewBuilder
    private var emptyProcessState: some View {
        if monitor.query.isEmpty {
            HStack(spacing: Space.sm) {
                ProgressView().controlSize(.small)
                Text(t("正在读取…", "Reading…"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.vertical, Space.md)
        } else {
            RestfulState(
                symbol: "magnifyingglass",
                title: t("没有匹配的进程", "No matching processes"),
                message: t("换个关键词，或者切换上面的范围。", "Try another term, or switch the scope above.")
            )
        }
    }

    private var processHeader: some View {
        HStack(spacing: Space.md) {
            Color.clear.frame(width: 18, height: 1)

            sortableHeader(.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("PID")
                .frame(width: 52, alignment: .trailing)

            sortableHeader(.memory).frame(width: 78, alignment: .trailing)
            sortableHeader(.started).frame(width: 92, alignment: .trailing)
            sortableHeader(.cpu).frame(width: 112, alignment: .trailing)

            Color.clear.frame(width: 56, height: 1)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(Palette.inkTertiary)
        .padding(.bottom, Space.xs)
    }

    private func sortableHeader(_ metric: ProcessSortMetric) -> some View {
        let isActive = monitor.processSort == metric
        return Button {
            withAnimation(.smooth(duration: 0.3)) {
                if isActive {
                    monitor.sortAscending.toggle()
                } else {
                    monitor.processSort = metric
                }
            }
        } label: {
            HStack(spacing: 3) {
                if metric == .name {
                    Text(metric.title)
                    if isActive { sortChevron }
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    Text(metric.title)
                    if isActive { sortChevron }
                }
            }
            .foregroundStyle(isActive ? Palette.flow : Palette.inkTertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            isActive
                ? t("再次点击可反向排序", "Click again to reverse the order")
                : t("按 \(metric.title) 排序", "Sort by \(metric.title)")
        )
    }

    private var sortChevron: some View {
        Image(systemName: monitor.sortAscending ? "chevron.up" : "chevron.down")
            .font(.system(size: 7, weight: .bold))
            .transition(.opacity)
    }

    private var footnote: some View {
        Text(
            t(
                "风扇转速和芯片温度需要系统底层权限才能读取，MacPleco 不去猜这些数字，所以只显示 macOS 自己公开的散热状态。GPU 显示的是整块显卡的负载：macOS 没有向普通 App 公开“每个进程的 GPU 占用”，能做到的工具都需要管理员权限。",
                "Fan speed and die temperature need privileged access to read. MacPleco won't guess at numbers, so it shows the thermal state macOS publishes instead. GPU figures cover the whole device: macOS exposes no per-process GPU share to ordinary apps, and every tool that reports one needs administrator access."
            )
        )
        .font(.system(size: 11))
        .foregroundStyle(Palette.inkTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Process row

private struct ProcessRow: View {
    let process: ProcessSample
    let sort: ProcessSortMetric
    let onReveal: () -> Void
    let onEnd: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Space.md) {
            ProcessIcon(process: process)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Space.sm) {
                    Text(process.name)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if process.isSystem {
                        Text(t("系统", "System"))
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Palette.chartViolet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background { Capsule().fill(Palette.chartViolet.opacity(0.14)) }
                    }
                }
                if !process.path.isEmpty {
                    Text(process.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 52, alignment: .trailing)

            Text(Bytes.formatMemory(process.memory))
                .font(.system(size: 11.5, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(sort == .memory ? Palette.ink : Palette.inkSecondary)
                .contentTransition(.numericText())
                .frame(width: 78, alignment: .trailing)

            Text(startedText)
                .font(.system(size: 10.5, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(sort == .started ? Palette.ink : Palette.inkSecondary)
                .frame(width: 92, alignment: .trailing)
                .help(startedHelp)

            HStack(spacing: Space.sm) {
                CapacityBar(
                    fraction: min(1, process.cpu / 100),
                    tint: cpuTint,
                    height: 4
                )
                .frame(width: 52)
                Text(String(format: "%.1f%%", process.cpu))
                    .font(.system(size: 11.5, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(sort == .cpu ? Palette.ink : Palette.inkSecondary)
                    .contentTransition(.numericText())
                    .frame(width: 48, alignment: .trailing)
            }
            .frame(width: 112, alignment: .trailing)

            HStack(spacing: Space.xs) {
                if hovering {
                    Button(action: onReveal) {
                        Image(systemName: "folder")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.flow)
                    }
                    .buttonStyle(.plain)
                    .disabled(process.revealURL == nil)
                    .help(t("在访达中显示", "Show in Finder"))

                    Button(action: onEnd) {
                        Image(systemName: "xmark.octagon")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.danger)
                    }
                    .buttonStyle(.plain)
                    .help(t("结束进程…", "End process…"))
                }
            }
            .frame(width: 56, alignment: .trailing)
            .animation(.smooth(duration: 0.18), value: hovering)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Space.sm)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .fill(Palette.aqua.opacity(hovering ? 0.06 : 0))
        }
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.2), value: hovering)
        .contextMenu {
            Button(action: onReveal) {
                Label(t("在访达中显示", "Show in Finder"), systemImage: "folder")
            }
            .disabled(process.revealURL == nil)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(process.path, forType: .string)
            } label: {
                Label(t("复制完整路径", "Copy Full Path"), systemImage: "doc.on.doc")
            }
            .disabled(process.path.isEmpty)

            Divider()

            Button(t("结束进程…", "End process…"), role: .destructive, action: onEnd)
        }
    }

    /// System processes get the violet used for "system" everywhere else on
    /// this page, so a busy row reads as *whose* work it is before you read
    /// the name. Anything genuinely hot goes amber regardless.
    private var cpuTint: Color {
        if process.cpu > 60 { return Palette.caution }
        return process.isSystem ? Palette.chartViolet : Palette.chartTeal
    }

    private var startedText: String {
        guard let started = process.started else { return "—" }
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 60 { return t("刚刚", "just now") }
        return RelativeTime.duration(elapsed)
    }

    private var startedHelp: String {
        guard let started = process.started else {
            return t("启动时间未知", "Start time unknown")
        }
        return t(
            "启动于 \(Self.stamp.string(from: started))",
            "Started \(Self.stamp.string(from: started))"
        )
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Process icon

/// Apps get their real icon; anything belonging to the system gets a quiet
/// gear, which is also the visual half of telling the two apart. Lookups hit
/// the disk, so they are memoised by path.
private struct ProcessIcon: View {
    let process: ProcessSample

    var body: some View {
        if !process.isSystem, let icon = ProcessIconCache.shared.icon(for: process) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: process.isSystem ? "gearshape.fill" : "terminal.fill")
                .font(.system(size: 10))
                .foregroundStyle(Palette.inkFaint)
                .frame(width: 18, height: 18)
        }
    }
}

@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()
    private var cache: [String: NSImage?] = [:]

    func icon(for process: ProcessSample) -> NSImage? {
        guard let bundle = ProcessSample.enclosingBundle(of: process.path) else { return nil }
        if let hit = cache[bundle] { return hit }
        let image = NSWorkspace.shared.icon(forFile: bundle)
        image.size = NSSize(width: 36, height: 36)
        if cache.count > 400 { cache.removeAll() }
        cache[bundle] = image
        return image
    }
}

// MARK: - Core grid

/// One slim bar per logical core. The point is shape recognition — "one core
/// pinned" versus "everything busy" — not numbers.
private struct CoreGrid: View {
    let loads: [Double]

    var body: some View {
        if loads.isEmpty {
            Color.clear
        } else {
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(Array(loads.enumerated()), id: \.offset) { _, load in
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(load > 0.85 ? Palette.caution : Palette.chartTeal)
                                .frame(height: max(2, geo.size.height * load))
                        }
                    }
                }
            }
            .animation(.smooth(duration: 0.5), value: loads)
            .accessibilityLabel(t("每个核心的负载", "Per-core load"))
        }
    }
}
