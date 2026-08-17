import SwiftUI

/// The app's one large, deliberate visual.
///
/// It is a gauge, not an ornament: the water level *is* the share of the disk
/// in use, and the bright arc *is* the share MacPleco can give back. A
/// decorative globe would carry the same emotional weight and tell the user
/// nothing, so everything drawn here is bound to a number.
///
/// The surface only ripples while work is happening. Perpetual motion in a
/// utility whose whole job is to be unobtrusive would be both distracting and,
/// on a laptop, quietly expensive.
public struct DepthRing: View {
    private let usedFraction: Double
    private let reclaimableFraction: Double
    private let isWorking: Bool
    private let caption: String
    private let value: String
    private let unit: String

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

    public var body: some View {
        ZStack {
            water
            rings
            readout
        }
        .frame(width: 244, height: 244)
        .animation(.smooth(duration: 0.8), value: usedFraction)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption) \(value) \(unit)")
    }

    // MARK: - Water

    private var water: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isWorking)) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 1.1
                let bounds = CGRect(origin: .zero, size: size)
                    .insetBy(dx: 14, dy: 14)

                context.clip(to: Path(ellipseIn: bounds))

                // Level rises from the bottom of the circle as the disk fills.
                let level = bounds.maxY - bounds.height * usedFraction
                let amplitude: CGFloat = isWorking ? 5 : 1.5

                context.fill(
                    wavePath(in: bounds, level: level, phase: phase, amplitude: amplitude, wavelength: bounds.width / 1.15),
                    with: .linearGradient(
                        Gradient(colors: [
                            Palette.aqua.opacity(0.42),
                            Palette.aquaDeep.opacity(0.20)
                        ]),
                        startPoint: CGPoint(x: bounds.midX, y: level),
                        endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
                    )
                )

                // A second, slower wave gives the surface some depth without
                // reading as two separate things.
                context.fill(
                    wavePath(in: bounds, level: level + 5, phase: -phase * 0.65, amplitude: amplitude * 0.7, wavelength: bounds.width / 0.8),
                    with: .color(Palette.aqua.opacity(0.16))
                )
            }
        }
    }

    private func wavePath(
        in bounds: CGRect,
        level: CGFloat,
        phase: Double,
        amplitude: CGFloat,
        wavelength: CGFloat
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

    private var rings: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.hairlineStrong, lineWidth: 1)

            Circle()
                .inset(by: 5)
                .trim(from: 0, to: usedFraction)
                .stroke(
                    Palette.inkFaint,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // The reclaimable slice starts where the used arc ends, so the two
            // read as one bar: "this much is full, and this much of it is junk".
            Circle()
                .inset(by: 5)
                .trim(
                    from: max(0, usedFraction - reclaimableFraction),
                    to: usedFraction
                )
                .stroke(
                    Palette.aquaSweep,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.aqua.opacity(0.5), radius: 8)
        }
    }

    // MARK: - Readout

    private var readout: some View {
        VStack(spacing: Space.xxs) {
            Text(caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
