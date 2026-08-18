import SwiftUI

/// The water the whole interface lives in.
///
/// Liquid Glass is refraction: a glass panel over a featureless background is
/// indistinguishable from a flat one, which is exactly what the first build
/// looked like in light appearance. This view exists to give the glass
/// something to bend — a base gradient with four large, slow, blurred colour
/// fields drifting behind everything.
///
/// Restraint rules: the drift cycle is over a minute long, amplitude is small,
/// the whole layer freezes under Reduce Motion, and it renders at 12 fps —
/// blur hides the stepping and the energy cost stays negligible.
public struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Set while a scan or clean is running; the water moves a little more.
    var energetic: Bool = false

    public init(energetic: Bool = false) {
        self.energetic = energetic
    }

    public var body: some View {
        ZStack {
            Palette.tankGradient

            TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let minSide = min(size.width, size.height)
                    let drift = energetic ? 1.6 : 1.0

                    blob(
                        &context,
                        color: Palette.auroraAqua,
                        center: orbit(t, size, cx: 0.22, cy: 0.24, rx: 0.06, ry: 0.05, period: 67, phase: 0),
                        radius: minSide * 0.52 * breathe(t, period: 41, phase: 1.2, amount: 0.06 * drift)
                    )
                    blob(
                        &context,
                        color: Palette.auroraSky,
                        center: orbit(t, size, cx: 0.82, cy: 0.30, rx: 0.05, ry: 0.07, period: 83, phase: 2.1),
                        radius: minSide * 0.46 * breathe(t, period: 53, phase: 0.4, amount: 0.05 * drift)
                    )
                    blob(
                        &context,
                        color: Palette.auroraViolet,
                        center: orbit(t, size, cx: 0.68, cy: 0.85, rx: 0.07, ry: 0.05, period: 71, phase: 4.0),
                        radius: minSide * 0.44 * breathe(t, period: 47, phase: 2.6, amount: 0.05 * drift)
                    )
                    blob(
                        &context,
                        color: Palette.auroraWarm,
                        center: orbit(t, size, cx: 0.16, cy: 0.88, rx: 0.05, ry: 0.06, period: 89, phase: 5.3),
                        radius: minSide * 0.36 * breathe(t, period: 59, phase: 3.8, amount: 0.04 * drift)
                    )
                }
                .blur(radius: 90)
            }

            // A faint vertical veil keeps the top of the window quietest, so
            // titles and toolbars always sit on calm water.
            LinearGradient(
                colors: [Palette.shallow.opacity(0.55), .clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func orbit(
        _ t: Double, _ size: CGSize,
        cx: Double, cy: Double, rx: Double, ry: Double,
        period: Double, phase: Double
    ) -> CGPoint {
        let angle = (t / period) * 2 * .pi + phase
        return CGPoint(
            x: size.width * (cx + rx * cos(angle)),
            y: size.height * (cy + ry * sin(angle * 0.9))
        )
    }

    private func breathe(_ t: Double, period: Double, phase: Double, amount: Double) -> Double {
        1.0 + amount * sin((t / period) * 2 * .pi + phase)
    }

    private func blob(_ context: inout GraphicsContext, color: Color, center: CGPoint, radius: Double) {
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}
