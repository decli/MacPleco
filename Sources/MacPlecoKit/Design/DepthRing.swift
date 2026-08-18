import SwiftUI

/// The app's one large, deliberate visual: a porthole into the tank.
///
/// It is a gauge, not an ornament — the water level *is* the share of the disk
/// in use, and the bright arc *is* the share MacPleco can give back. While a
/// scan runs the water stirs, bubbles rise and a sonar arc sweeps; at rest the
/// surface settles to a slow breathing swell. Reduce Motion freezes all of it.
public struct DepthRing: View {
    private let usedFraction: Double
    private let reclaimableFraction: Double
    private let isWorking: Bool
    private let caption: String
    private let value: String
    private let unit: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        usedFraction: Double,
        reclaimableFraction: Double,
        isWorking: Bool,
        caption: String,
        value: String,
        unit: String
    ) {
        self.usedFraction = min(1, max(0, usedFraction))
        self.reclaimableFraction = min(1, max(0, reclaimableFraction))
        self.isWorking = isWorking
        self.caption = caption
        self.value = value
        self.unit = unit
    }

    private var side: CGFloat { 268 }

    public var body: some View {
        ZStack {
            water
            rings
            readout
        }
        .frame(width: side, height: side)
        .animation(.smooth(duration: 0.8), value: usedFraction)
        .animation(.smooth(duration: 0.8), value: reclaimableFraction)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption) \(value) \(unit)")
    }

    // MARK: - Water

    @ViewBuilder
    private var water: some View {
        // The overview must genuinely idle. A TimelineView that ticks at even
        // 10 fps keeps the entire glass hierarchy compositing forever. Animate
        // only while a scan is visibly in progress; otherwise render one frame.
        if isWorking && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                waterFrame(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            waterFrame(at: 0)
        }
    }

    private func waterFrame(at t: TimeInterval) -> some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 17, dy: 17)
            context.clip(to: Path(ellipseIn: bounds))

            // A faint inner pool so the porthole reads as filled glass even
            // above the waterline.
            context.fill(
                Path(ellipseIn: bounds),
                with: .linearGradient(
                    Gradient(colors: [Palette.aqua.opacity(0.05), Palette.flow.opacity(0.10)]),
                    startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                    endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
                )
            )

            let level = bounds.maxY - bounds.height * usedFraction
            let amplitude: CGFloat = isWorking ? 5.5 : 2
            let phase = t * (isWorking ? 1.5 : 0.7)

            context.fill(
                wavePath(in: bounds, level: level, phase: phase, amplitude: amplitude, wavelength: bounds.width / 1.1),
                with: .linearGradient(
                    Gradient(colors: [
                        Palette.aquaBright.opacity(0.55),
                        Palette.aqua.opacity(0.40),
                        Palette.aquaDeep.opacity(0.22)
                    ]),
                    startPoint: CGPoint(x: bounds.midX, y: level),
                    endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
                )
            )
            context.fill(
                wavePath(in: bounds, level: level + 6, phase: -phase * 0.6, amplitude: amplitude * 0.7, wavelength: bounds.width / 0.8),
                with: .color(Palette.aqua.opacity(0.18))
            )

            // Surface glint.
            var glint = Path()
            glint.move(to: CGPoint(x: bounds.minX, y: level))
            var x = bounds.minX
            while x <= bounds.maxX {
                let angle = Double(x / (bounds.width / 1.1)) * 2 * .pi + phase
                glint.addLine(to: CGPoint(x: x, y: level + amplitude * CGFloat(sin(angle))))
                x += 3
            }
            context.stroke(glint, with: .color(.white.opacity(0.35)), lineWidth: 1)

            if isWorking {
                drawBubbles(&context, bounds: bounds, level: level, t: t)
            }
        }
    }

    private func drawBubbles(_ context: inout GraphicsContext, bounds: CGRect, level: CGFloat, t: Double) {
        let depth = bounds.maxY - level
        guard depth > 24 else { return }
        for index in 0..<16 {
            let seed = Double(index) * 97.31
            let speed = 0.10 + 0.05 * Double(index % 5)
            let progress = (t * speed + seed).truncatingRemainder(dividingBy: 1)
            let sway = sin(t * 1.3 + seed) * 7
            let x = bounds.minX + bounds.width * (0.12 + 0.76 * ((seed / 9.7).truncatingRemainder(dividingBy: 1))) + sway
            let y = bounds.maxY - CGFloat(progress) * depth
            guard y > level + 8 else { continue }
            let radius = 1.4 + CGFloat(index % 3)
            let fade = min(1, (y - level - 8) / 30)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(0.35 * fade))
            )
        }
    }

    private func wavePath(
        in bounds: CGRect, level: CGFloat, phase: Double,
        amplitude: CGFloat, wavelength: CGFloat
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: level))
        var x = bounds.minX
        while x <= bounds.maxX {
            let angle = Double(x / max(1, wavelength)) * 2 * .pi + phase
            path.addLine(to: CGPoint(x: x, y: level + amplitude * CGFloat(sin(angle))))
            x += 3
        }
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    // MARK: - Rings

    private let ringWidth: CGFloat = 11

    private var rings: some View {
        ZStack {
            // Porthole rim.
            Circle()
                .strokeBorder(Palette.hairlineStrong, lineWidth: 1)

            // Full track, visible in both appearances.
            Circle()
                .inset(by: 6)
                .stroke(Color.veil(0.10, light: 0.08), style: StrokeStyle(lineWidth: ringWidth))

            // Used share of the disk.
            Circle()
                .inset(by: 6)
                .trim(from: 0, to: usedFraction)
                .stroke(
                    Color.veil(0.26, light: 0.22),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if isWorking {
                sonar
            } else {
                reclaimArc
            }
        }
    }

    /// The reclaimable slice ends where the used arc ends, so the two read as
    /// one bar: "this much is full, and this much of it is junk".
    @ViewBuilder
    private var reclaimArc: some View {
        let from = max(0, usedFraction - reclaimableFraction)
        Circle()
            .inset(by: 6)
            .trim(from: from, to: usedFraction)
            .stroke(
                AngularGradient(
                    colors: [Palette.aquaBright, Palette.aqua, Palette.flow],
                    center: .center,
                    startAngle: .degrees(from * 360),
                    endAngle: .degrees(usedFraction * 360)
                ),
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: Palette.aqua.opacity(0.55), radius: 9)

        // Endpoint bead — gives the arc a head, like a diver's light.
        if reclaimableFraction > 0.004 {
            Circle()
                .fill(.white)
                .frame(width: 6.5, height: 6.5)
                .shadow(color: Palette.aquaBright.opacity(0.9), radius: 5)
                .offset(y: -(side / 2 - 6 - ringWidth / 2))
                .rotationEffect(.degrees(usedFraction * 360))
        }
    }

    /// While scanning, a sweeping arc replaces the reclaim slice.
    private var sonar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .inset(by: 6)
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(
                        colors: [Palette.aqua.opacity(0), Palette.aquaBright],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(80)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees((t * 120).truncatingRemainder(dividingBy: 360) - 90))
                .shadow(color: Palette.aqua.opacity(0.5), radius: 8)
        }
    }

    // MARK: - Readout

    private var readout: some View {
        VStack(spacing: Space.xxs) {
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .shadow(color: Palette.shallow.opacity(0.6), radius: 6)
    }
}
