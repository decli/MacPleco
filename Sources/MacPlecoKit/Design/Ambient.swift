import SwiftUI

/// The water the whole interface lives in.
///
/// Liquid Glass is refraction: a glass panel over a featureless background is
/// indistinguishable from a flat one. This layer gives the glass something to
/// bend — a base gradient with four soft colour fields drifting behind the
/// content.
///
/// Implementation note, learned the hard way: the first version drew the
/// fields in a `Canvas` inside a `TimelineView`, blurred them by 90pt and
/// wrapped everything in `drawingGroup()`. That combination re-rasterises the
/// whole window on the main thread twelve times a second and froze the app on
/// launch. A `RadialGradient` *is* a soft blob — no blur pass, no timeline, no
/// offscreen rasterisation — and its drift is a plain repeat-forever offset
/// animation the compositor runs off the main thread for free.
public struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    public init() {}

    public var body: some View {
        ZStack {
            Palette.tankGradient

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    blob(Palette.auroraAqua, diameter: side * 1.30, period: 47) {
                        CGPoint(x: geo.size.width * 0.20, y: geo.size.height * 0.22)
                    } sway: {
                        CGSize(width: 46, height: 30)
                    }
                    blob(Palette.auroraSky, diameter: side * 1.15, period: 59) {
                        CGPoint(x: geo.size.width * 0.84, y: geo.size.height * 0.28)
                    } sway: {
                        CGSize(width: -38, height: 44)
                    }
                    blob(Palette.auroraViolet, diameter: side * 1.10, period: 53) {
                        CGPoint(x: geo.size.width * 0.68, y: geo.size.height * 0.86)
                    } sway: {
                        CGSize(width: 40, height: -34)
                    }
                    blob(Palette.auroraWarm, diameter: side * 0.90, period: 67) {
                        CGPoint(x: geo.size.width * 0.14, y: geo.size.height * 0.88)
                    } sway: {
                        CGSize(width: -30, height: -26)
                    }
                }
            }

            // A faint veil keeps the top of the window quietest, so titles and
            // toolbars always sit on calm water.
            LinearGradient(
                colors: [Palette.shallow.opacity(0.55), .clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            drifting = true
        }
    }

    private func blob(
        _ color: Color,
        diameter: CGFloat,
        period: Double,
        at position: () -> CGPoint,
        sway: () -> CGSize
    ) -> some View {
        let home = position()
        let amount = sway()
        return Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(home)
            .offset(
                x: drifting ? amount.width : -amount.width,
                y: drifting ? amount.height : -amount.height
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: period).repeatForever(autoreverses: true),
                value: drifting
            )
    }
}
