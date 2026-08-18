import SwiftUI

// MARK: - Motion primitives

/// A gentle rise-and-settle on hover. Applied to cards so the interface
/// answers the pointer without shouting.
public struct HoverLift: ViewModifier {
    @State private var hovering = false
    var enabled = true

    public func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && hovering ? 1.006 : 1)
            .shadow(
                color: .black.opacity(enabled && hovering ? 0.10 : 0.05),
                radius: enabled && hovering ? 20 : 12,
                y: enabled && hovering ? 10 : 5
            )
            .onHover { inside in
                guard enabled else { return }
                withAnimation(.smooth(duration: 0.25)) { hovering = inside }
            }
    }
}

/// Fade-and-rise entrance, staggered by index. Sections pass 0, 1, 2… to
/// their top-level blocks so a page assembles instead of popping.
public struct StaggerIn: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .onAppear {
                guard !shown else { return }
                withAnimation(.smooth(duration: 0.55).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    public func hoverLift(_ enabled: Bool = true) -> some View {
        modifier(HoverLift(enabled: enabled))
    }

    public func rises(_ index: Int) -> some View {
        modifier(StaggerIn(index: index))
    }
}

// MARK: - Skeleton

/// A shimmering placeholder block for content that is still being measured.
public struct SkeletonBlock: View {
    var radius: CGFloat = Radius.chip
    @State private var pulse = false

    public init(radius: CGFloat = Radius.chip) {
        self.radius = radius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Palette.wellFill)
            .opacity(pulse ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Card

/// A floating pane of glass. The default container for everything that is not
/// a full-bleed visualisation.
public struct GlassCard<Content: View>: View {
    private let padding: CGFloat
    private let radius: CGFloat
    private let tint: Color?
    private let lifts: Bool
    private let content: Content

    public init(
        padding: CGFloat = Space.lg,
        radius: CGFloat = Radius.panel,
        tint: Color? = nil,
        lifts: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.tint = tint
        self.lifts = lifts
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(radius: radius, tint: tint)
            .hoverLift(lifts)
    }
}

// MARK: - Page header

/// The heading every section opens with. Title carries the section name, the
/// support line says what the page will do for you in plain words — the two
/// together are the only orientation a first-time user gets, so neither is
/// decorative.
public struct PageHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String
    private let trailing: Trailing

    public init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Space.md)
            trailing
        }
    }
}

// MARK: - Buttons

/// The single prominent action on a page. There is never more than one.
public struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.aqua
    var wide: Bool = false

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, wide ? Space.xxl : Space.xl)
                .padding(.vertical, Space.md)
                .frame(maxWidth: wide ? .infinity : nil)
                // Use the system material directly so highlights, lensing and
                // pointer response follow the current macOS glass appearance.
                .glassEffect(.regular.tint(tint).interactive(), in: Capsule(style: .continuous))
                .opacity(configuration.isPressed ? 0.82 : 1)
                .contentShape(Capsule(style: .continuous))
        } else {
            configuration.label
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, wide ? Space.xxl : Space.xl)
                .padding(.vertical, Space.md)
                .frame(maxWidth: wide ? .infinity : nil)
                .background {
                    Capsule(style: .continuous)
                        .fill(tint.gradient)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
                                .blendMode(.plusLighter)
                        }
                }
                .shadow(color: tint.opacity(0.34), radius: 14, y: 5)
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
                .contentShape(Capsule(style: .continuous))
        }
    }
}

/// Quiet actions that sit beside the primary one.
public struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Palette.ink

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .glassSurface(Capsule(style: .continuous), level: .interactive)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
            .contentShape(Capsule(style: .continuous))
    }
}

// MARK: - Chips

/// How risky is it to remove this?
///
/// Every removable thing in the app carries one of these. It is the main device
/// that lets a non-technical person act confidently without reading paths.
public enum Safety: Sendable {
    case safe
    case review
    case careful

    public var label: String {
        switch self {
        case .safe: return t("随时可删", "Safe to remove")
        case .review: return t("建议看一眼", "Worth a look")
        case .careful: return t("请谨慎", "Be careful")
        }
    }

    public var tint: Color {
        switch self {
        case .safe: return Palette.aqua
        case .review: return Palette.caution
        case .careful: return Palette.danger
        }
    }

    public var symbol: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .review: return "eye.fill"
        case .careful: return "exclamationmark.triangle.fill"
        }
    }
}

public struct SafetyChip: View {
    private let safety: Safety
    private let compact: Bool

    public init(_ safety: Safety, compact: Bool = false) {
        self.safety = safety
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: safety.symbol)
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            if !compact {
                Text(safety.label)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(safety.tint)
        .padding(.horizontal, compact ? Space.xs : Space.sm)
        .padding(.vertical, compact ? 2 : 3)
        .background {
            Capsule(style: .continuous)
                .fill(safety.tint.opacity(0.14))
        }
        .accessibilityLabel(safety.label)
    }
}

// MARK: - Checkbox

/// A checkbox with a third, indeterminate state.
///
/// AppKit has one and SwiftUI does not, and the mixed state matters here: a
/// category showing a dash tells you at a glance that you have made a choice
/// inside it, which a plain on/off box cannot.
public struct TriStateBox: View {
    /// Named `Mark` rather than `State` so it cannot shadow SwiftUI's property
    /// wrapper inside this type.
    public enum Mark { case off, mixed, on }

    private let state: Mark
    private let tint: Color
    private let enabled: Bool
    private let action: () -> Void

    public init(
        state: Mark,
        tint: Color = Palette.aqua,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.state = state
        self.tint = tint
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(state == .off ? AnyShapeStyle(Color.clear) : AnyShapeStyle(tint.gradient))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        state == .off ? Palette.inkFaint : Color.clear,
                        lineWidth: 1.2
                    )
                if state == .on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                } else if state == .mixed {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 8, height: 2)
                }
            }
            .frame(width: 17, height: 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.snappy(duration: 0.18), value: state)
        .accessibilityAddTraits(state == .on ? [.isSelected] : [])
    }
}

// MARK: - Capacity bar

/// A slim horizontal fill. Used in the sidebar footer and in list rows where a
/// ring would be too heavy.
public struct CapacityBar: View {
    private let fraction: Double
    private let tint: Color
    private let height: CGFloat

    public init(fraction: Double, tint: Color = Palette.aqua, height: CGFloat = 6) {
        self.fraction = min(1, max(0, fraction))
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Palette.wellFill)
                Capsule(style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: max(fraction > 0 ? height : 0, geo.size.width * fraction))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.5), value: fraction)
    }
}

// MARK: - Empty & loading states

/// Shown when a scan found nothing. Deliberately congratulatory rather than
/// apologetic — finding no junk is a good outcome, not an empty result.
public struct RestfulState: View {
    private let symbol: String
    private let title: String
    private let message: String

    public init(symbol: String = "checkmark.seal", title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.aqua)
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.huge)
    }
}

// MARK: - Section label

public struct SectionLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Palette.inkTertiary)
    }
}
