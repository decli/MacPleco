import SwiftUI

// Every macOS 26 Liquid Glass API the app uses is funnelled through this file.
// Two reasons: the rest of the codebase stays free of availability checks, and
// when a signature shifts between SDKs there is exactly one place to fix.
//
// On macOS 15 each entry point degrades to the closest native equivalent —
// `Material` blur plus a hairline — so the app looks deliberate there too
// rather than merely unstyled.

// MARK: - Glass surface

/// How much the surface should assert itself.
public enum GlassLevel {
    /// Floating panels, cards, sidebars.
    case regular
    /// Interactive controls that should respond to pointer proximity.
    case interactive
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let level: GlassLevel
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(resolvedGlass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .strokeBorder(Palette.hairlineStrong, lineWidth: 0.5)
                }
                .overlay {
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
        }
    }

    @available(macOS 26.0, *)
    private var resolvedGlass: Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if level == .interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

extension View {
    /// Applies a Liquid Glass surface clipped to `shape`.
    public func glassSurface<S: InsettableShape>(
        _ shape: S,
        level: GlassLevel = .regular,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassSurface(shape: shape, level: level, tint: tint))
    }

    /// Convenience for the common rounded-rectangle panel.
    public func glassPanel(
        radius: CGFloat = Radius.card,
        level: GlassLevel = .regular,
        tint: Color? = nil
    ) -> some View {
        glassSurface(
            RoundedRectangle(cornerRadius: radius, style: .continuous),
            level: level,
            tint: tint
        )
    }
}

// MARK: - Morphing container

/// Wraps content so that sibling glass surfaces blend and morph into one
/// another instead of stacking as separate panes. A no-op before macOS 26.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Background extension

extension View {
    /// Lets a view's material bleed underneath adjacent glass chrome (the
    /// sidebar, the toolbar) so the window reads as one continuous body of
    /// water rather than tiled rectangles.
    @ViewBuilder
    public func bleedUnderChrome() -> some View {
        if #available(macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }

    /// Softens the top edge of a scroll view where content passes under the
    /// toolbar, matching the system's own scroll-edge treatment.
    @ViewBuilder
    public func softScrollEdges() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

// MARK: - Symbol motion

extension View {
    /// A restrained "this is working" pulse on an SF Symbol.
    @ViewBuilder
    public func breathing(_ active: Bool) -> some View {
        self.symbolEffect(.pulse, options: .repeating, isActive: active)
    }
}
