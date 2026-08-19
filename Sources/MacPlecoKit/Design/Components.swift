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

// MARK: - Stat card

/// The one card used for every headline number in the app.
///
/// The Overview and Monitor grids used to build their own card, and each let
/// its optional pieces collapse when unused — an `EmptyView` carrying a
/// `.frame(height:)` still occupies nothing — so a card with a progress bar or
/// a chart stood taller than its neighbours and the row centred the short ones
/// against it. Every slot here is *reserved* whether or not it is filled, and
/// the page declares the slot heights once for the whole grid, so a row of
/// these is equal-height by construction rather than by luck.
public struct StatCard<Chart: View, Extra: View>: View {
    private let symbol: String
    private let label: String
    private let value: String
    private let detail: String
    private let tint: Color
    private let badge: String?
    private let progress: Double?
    private let chartHeight: CGFloat?
    private let extraHeight: CGFloat?
    private let reservesProgress: Bool
    private let detailLines: Int
    private let chart: Chart
    private let extra: Extra

    public init(
        symbol: String,
        label: String,
        value: String,
        detail: String,
        tint: Color = Palette.aqua,
        badge: String? = nil,
        progress: Double? = nil,
        reservesProgress: Bool = true,
        detailLines: Int = 2,
        chartHeight: CGFloat? = nil,
        extraHeight: CGFloat? = nil,
        @ViewBuilder chart: () -> Chart = { EmptyView() },
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) {
        self.symbol = symbol
        self.label = label
        self.value = value
        self.detail = detail
        self.tint = tint
        self.badge = badge
        self.progress = progress
        self.reservesProgress = reservesProgress
        self.detailLines = detailLines
        self.chartHeight = chartHeight
        self.extraHeight = extraHeight
        self.chart = chart()
        self.extra = extra()
    }

    public var body: some View {
        GlassCard(padding: Space.lg, radius: Radius.card, lifts: true) {
            VStack(alignment: .leading, spacing: Space.sm) {
                header

                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(height: 29, alignment: .leading)

                // `ZStack` with a clear floor rather than the content alone:
                // it holds the slot's height even when what goes in it is an
                // `EmptyView`.
                if let chartHeight {
                    ZStack { Color.clear; chart }
                        .frame(height: chartHeight)
                }

                if let extraHeight {
                    ZStack { Color.clear; extra }
                        .frame(height: extraHeight)
                }

                if reservesProgress {
                    ZStack {
                        Color.clear
                        if let progress {
                            CapacityBar(fraction: progress, tint: tint, height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(detailLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: CGFloat(detailLines) * 14, alignment: .topLeading)
            }
            // Absorbs any residual difference, so the tallest card in a row
            // sets the height and the others fill it instead of floating.
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 11.5))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2.5)
                    .background { Capsule().fill(tint.opacity(0.14)) }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(height: 17)
    }
}

/// A row of stat cards on explicit, equal-width columns.
///
/// The ragged rows this replaces were not a spacing bug — measured at runtime,
/// `GridItem(.adaptive(minimum:))` lays four cards out in exactly the same
/// frames as four `.flexible()` columns. The fault is the *column count*.
/// Adaptive fits as many columns as the container allows and leaves the rest
/// empty: at the default window width four cards get three columns and land as
/// a row of three with one card stranded underneath, and in a wider container
/// they get five columns and stop short of the right edge by a whole card.
///
/// Counting the cards fixes both. There is never a column without a card in
/// it, and when they cannot all share one row the split is even (2 + 2 rather
/// than 3 + 1), so a wrapped row still reads as a deliberate grid.
///
/// Top alignment matters too: without it a shorter card is centred against a
/// taller neighbour, which is the other half of what made these rows ragged.
public struct StatCardGrid<Content: View>: View {
    private let minimum: CGFloat
    private let spacing: CGFloat
    private let content: Content

    /// Zero until the first layout pass reports a width; one column is the
    /// honest answer for an unknown container and settles in the same frame.
    @State private var width: CGFloat = 0

    public init(
        minimum: CGFloat,
        spacing: CGFloat = Space.md,
        @ViewBuilder content: () -> Content
    ) {
        self.minimum = minimum
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        // `Group(subviews:)` is what makes the count trustworthy: it is the
        // cards actually in the row, not a number the call site has to
        // remember to update.
        Group(subviews: content) { cards in
            LazyVGrid(columns: columns(for: cards.count), spacing: spacing) {
                ForEach(cards) { $0 }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }

    private func columns(for cards: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
            count: columnCount(for: cards)
        )
    }

    /// n columns of `minimum` need n − 1 gutters, so the fit test is on
    /// `width + spacing` against `minimum + spacing`. What fits is only the
    /// ceiling; the count returned is the widest even split at or below it.
    private func columnCount(for cards: Int) -> Int {
        let fitting = Int((width + spacing) / (minimum + spacing))
        let ceiling = max(1, min(cards, fitting))
        guard ceiling > 1 else { return 1 }

        // An even split is worth giving up one column for, but not worth
        // collapsing to a single file: five cards in a four-card row stay
        // 4 + 1 rather than becoming one long column.
        let floor = (ceiling + 1) / 2
        for candidate in stride(from: ceiling, through: floor, by: -1)
        where cards % candidate == 0 {
            return candidate
        }
        return ceiling
    }
}

// MARK: - Legend

/// A colour swatch and its meaning. Any chart plotting more than one series
/// carries these, so the colours are decodable instead of decorative.
public struct LegendDot: View {
    private let color: Color
    private let label: String
    private let value: String?

    public init(_ color: Color, _ label: String, value: String? = nil) {
        self.color = color
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Palette.inkTertiary)
            if let value {
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
        .fixedSize()
    }
}

// MARK: - Segmented bar

/// A stacked bar whose segments each carry their own colour, for a total made
/// of distinguishable parts — memory split into app, wired and compressed,
/// rather than one anonymous fill.
public struct SegmentedBar: View {
    public struct Segment: Identifiable, Equatable {
        public let id: String
        public let fraction: Double
        public let color: Color

        public init(id: String, fraction: Double, color: Color) {
            self.id = id
            self.fraction = max(0, fraction)
            self.color = color
        }
    }

    private let segments: [Segment]
    private let height: CGFloat

    public init(segments: [Segment], height: CGFloat = 6) {
        self.segments = segments
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.color.gradient)
                        .frame(width: max(0, geo.size.width * min(1, segment.fraction)))
                }
                Spacer(minLength: 0)
            }
            .frame(height: height)
            .background { Capsule(style: .continuous).fill(Palette.wellFill) }
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.45), value: segments)
    }
}

// MARK: - Sparkline

/// One or more series over a shared time window.
///
/// Each series keeps its own colour so two quantities on one chart — user
/// versus system CPU, download versus upload — stay tellable apart. Series are
/// normalised against the *combined* peak so their relative heights stay
/// honest; normalising each against its own peak would draw a trickle of
/// upload as tall as a flood of download.
public struct Sparkline: View {
    public struct Series {
        public let values: [Double]
        public let color: Color
        public let filled: Bool

        public init(values: [Double], color: Color, filled: Bool = true) {
            self.values = values
            self.color = color
            self.filled = filled
        }
    }

    private let series: [Series]

    public init(_ series: [Series]) {
        self.series = series
    }

    public init(values: [Double], tint: Color) {
        self.series = [Series(values: values, color: tint)]
    }

    public var body: some View {
        Canvas { context, size in
            let peak = max(series.flatMap(\.values).max() ?? 1, 0.0001)

            for entry in series {
                guard entry.values.count > 1 else { continue }
                let step = size.width / CGFloat(entry.values.count - 1)

                var line = Path()
                for (index, value) in entry.values.enumerated() {
                    let x = CGFloat(index) * step
                    let y = size.height - CGFloat(min(1, value / peak)) * size.height
                    if index == 0 {
                        line.move(to: CGPoint(x: x, y: y))
                    } else {
                        line.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                if entry.filled {
                    var fill = line
                    fill.addLine(to: CGPoint(x: size.width, y: size.height))
                    fill.addLine(to: CGPoint(x: 0, y: size.height))
                    fill.closeSubpath()
                    context.fill(
                        fill,
                        with: .linearGradient(
                            Gradient(colors: [entry.color.opacity(0.30), entry.color.opacity(0.02)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                }
                context.stroke(line, with: .color(entry.color), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Row interaction

/// Hover and press feedback for list rows.
///
/// Rows in this app are targets — uninstall, run, reveal — so they should feel
/// like it under the pointer. The scale is deliberately tiny: enough to confirm
/// the row is live, not enough to shuffle the layout around it.
public struct RowInteraction: ViewModifier {
    var radius: CGFloat = Radius.card
    var tint: Color = Palette.aqua

    @State private var hovering = false
    @State private var pressed = false

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(hovering ? 0.07 : 0))
            }
            .scaleEffect(pressed ? 0.992 : 1)
            .animation(.smooth(duration: 0.2), value: hovering)
            .animation(.snappy(duration: 0.14), value: pressed)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    public func rowInteraction(
        radius: CGFloat = Radius.card,
        tint: Color = Palette.aqua
    ) -> some View {
        modifier(RowInteraction(radius: radius, tint: tint))
    }
}

// MARK: - Count pill

/// A small running total, used where a selection builds up.
public struct CountPill: View {
    private let count: Int
    private let tint: Color

    public init(_ count: Int, tint: Color = Palette.aqua) {
        self.count = count
        self.tint = tint
    }

    public var body: some View {
        Text("\(count)")
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(tint.gradient) }
    }
}

// MARK: - Toolbar-style action bar

/// The persistent bar a page puts above a list of tickable things.
///
/// Earlier versions only revealed the run button once something was selected,
/// on the theory that a disabled button reads as broken chrome. In practice it
/// read as *no* button: nothing on screen said batch operation was possible.
/// The bar is always there, and says how many are selected.
public struct SelectionBar<Actions: View>: View {
    private let selectedCount: Int
    private let totalCount: Int
    private let allSelected: Bool
    private let onToggleAll: () -> Void
    private let actions: Actions

    public init(
        selectedCount: Int,
        totalCount: Int,
        allSelected: Bool,
        onToggleAll: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.allSelected = allSelected
        self.onToggleAll = onToggleAll
        self.actions = actions()
    }

    public var body: some View {
        HStack(spacing: Space.md) {
            TriStateBox(
                state: allSelected ? .on : (selectedCount > 0 ? .mixed : .off),
                action: onToggleAll
            )

            Button(action: onToggleAll) {
                Text(allSelected ? t("取消全选", "Deselect all") : t("全选", "Select all"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.flow)
            }
            .buttonStyle(.plain)

            HStack(spacing: Space.xs) {
                Text(t("已选", "Selected"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.inkTertiary)
                Text("\(selectedCount)")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(selectedCount > 0 ? Palette.ink : Palette.inkTertiary)
                Text("/ \(totalCount)")
                    .font(.system(size: 11)) 
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: Space.sm)

            actions
        }
        .animation(.smooth(duration: 0.25), value: selectedCount)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 2)
        .glassPanel(radius: Radius.row)
    }
}
