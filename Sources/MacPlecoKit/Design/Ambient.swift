import SwiftUI

/// The water the whole interface lives in.
///
/// Liquid Glass is refraction: a glass panel over a featureless background is
/// indistinguishable from a flat one. This layer gives the glass something to
/// bend — a base gradient with four soft colour fields behind the content.
///
/// The fields are STATIC, and that is the third design of this layer, each
/// cheaper than the last. v0.2 re-rasterised the window on the main thread
/// twelve times a second (Canvas + 90pt blur + drawingGroup) and froze the
/// app. The first fix drifted the fields with repeat-forever animations —
/// which kept the compositor re-rendering every piece of glass chrome at
/// display refresh, forever, for motion of 0.02pt per frame that no eye can
/// see. A cleaner that burns GPU while idle is lying about its purpose, so
/// the water now simply stands still: a RadialGradient *is* a soft light
/// field, the glass refracts it just the same, and the window idles
/// completely.
public struct AmbientBackground: View {

    public init() {}

    public var body: some View {
        ZStack {
            Palette.tankGradient

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    blob(
                        Palette.auroraAqua,
                        diameter: side * 1.30,
                        at: CGPoint(x: geo.size.width * 0.20, y: geo.size.height * 0.22)
                    )
                    blob(
                        Palette.auroraSky,
                        diameter: side * 1.15,
                        at: CGPoint(x: geo.size.width * 0.84, y: geo.size.height * 0.28)
                    )
                    blob(
                        Palette.auroraViolet,
                        diameter: side * 1.10,
                        at: CGPoint(x: geo.size.width * 0.68, y: geo.size.height * 0.86)
                    )
                    blob(
                        Palette.auroraWarm,
                        diameter: side * 0.90,
                        at: CGPoint(x: geo.size.width * 0.14, y: geo.size.height * 0.88)
                    )
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
    }

    private func blob(_ color: Color, diameter: CGFloat, at position: CGPoint) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(position)
    }
}
