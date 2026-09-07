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
                withAnimation(Motion.hover) { hovering = inside }
            }
    }
}

/// How many stagger steps the surrounding scaffold has already used.
///
/// `Page` draws its masthead group at step 0 and then sets this to 1, so a
/// page's own blocks keep passing 0, 1, 2… as they always did and still land
/// *after* the header rather than alongside it.
private struct StaggerBaseKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var staggerBase: Int {
        get { self[StaggerBaseKey.self] }
        set { self[StaggerBaseKey.self] = newValue }
    }
}

/// Fade-and-rise entrance, staggered by index.
public struct StaggerIn: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.staggerBase) private var base
    @State private var shown = false

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .onAppear {
                guard !shown else { return }
                withAnimation(Motion.enter.delay(Double(base + index) * Motion.enterStagger)) {
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

/// A shimmering placeholder. Its height must match the real row it stands in
/// for — Space's placeholders were 76pt against 65pt cards, so the page
/// visibly shrank the moment the data arrived.
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

// MARK: - Page note

/// One line of page-scoped guidance under the masthead: what this page will
/// and will not touch, or how to operate the thing below it.
///
/// Fixed at one line's height. It used to grow to 32pt whenever it carried a
/// button, which moved every block on the page down by 16 relative to the
/// same page without one.
public struct PageNote: View {
    private let symbol: String
    private let text: String
    private let tint: Color

    public init(symbol: String = "info.circle", _ text: String, tint: Color = Palette.inkTertiary) {
        self.symbol = symbol
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            // A fixed box, because SF Symbols of one point size do not share
            // one width or one baseline: free-sized, the glyph left the text
            // starting at x=304.5 on Tune and x=305 on Space, a hanging indent
            // that moved when you changed page.
            Image(systemName: symbol)
                .glyph(.caption, weight: .medium)
                .foregroundStyle(tint)
                .frame(width: 13, height: 13)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            Text(text)
                .font(Typo.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(text)
            Spacer(minLength: Space.sm)
        }
        .frame(height: Space.lg, alignment: .center)
    }
}

// MARK: - Safety

/// How risky is it to remove this?
///
/// Every removable thing in the app carries one of these. It is the main
/// device that lets a non-technical person act confidently without reading
/// paths.
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

// MARK: - Badge

/// One badge for the whole app.
///
/// It replaces nine separate implementations that between them used three
/// point sizes (9/10/11), four vertical insets (1.5/2/2.5/3), three weights,
/// two fills and two shapes — enough variation that no two labels in the app
/// sat on the same grid, and none of it meant anything.
public struct Badge: View {
    public enum Size {
        /// The default: safety chips, stat badges, "runs at login", "system".
        case standard
        /// Inside dense rows, where a standard badge would set the row height.
        case compact
    }

    public enum Style {
        /// A tinted wash behind tinted text. The tint carries the meaning.
        case tinted(Color)
        /// A quiet well behind tertiary text. For facts, not warnings.
        case neutral
        /// A filled count. Only inside a button that is already an action.
        case count(Color)
    }

    private let text: String?
    private let symbol: String?
    private let size: Size
    private let style: Style

    public init(
        _ text: String? = nil,
        symbol: String? = nil,
        size: Size = .standard,
        style: Style = .neutral
    ) {
        self.text = text
        self.symbol = symbol
        self.size = size
        self.style = style
    }

    /// The safety chip, which is a badge whose text, symbol and tint all come
    /// from one value.
    public init(_ safety: Safety, size: Size = .standard) {
        self.text = size == .standard ? safety.label : nil
        self.symbol = safety.symbol
        self.size = size
        self.style = .tinted(safety.tint)
    }

    /// A running total inside an action.
    public static func count(_ value: Int, tint: Color = Palette.aqua) -> Badge {
        Badge("\(value)", size: .standard, style: .count(tint))
    }

    public var body: some View {
        HStack(spacing: Space.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .glyph(.badge, weight: .bold)
            }
            if let text {
                Text(text)
                    .font(font)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, textOnlySymbol ? 0 : horizontalPadding)
        .frame(
            width: textOnlySymbol ? height : nil,
            height: height
        )
        .background { Capsule(style: .continuous).fill(fill) }
        .accessibilityLabel(text ?? "")
    }

    /// A compact badge carrying only a symbol is a square, not a stub capsule.
    private var textOnlySymbol: Bool { text == nil && symbol != nil }

    private var height: CGFloat { size == .standard ? 18 : 16 }
    private var horizontalPadding: CGFloat { size == .standard ? Space.sm : 6 }

    private var font: Font {
        if case .count = style { return Typo.captionNumeric.weight(.bold) }
        return size == .standard ? Typo.overline : Typo.tag
    }

    private var foreground: Color {
        switch style {
        case .tinted(let color): return color
        case .neutral: return Palette.inkTertiary
        case .count: return Palette.onAccent
        }
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .tinted(let color): return AnyShapeStyle(color.opacity(0.14))
        case .neutral: return AnyShapeStyle(Palette.wellFill)
        case .count(let color): return AnyShapeStyle(color.gradient)
        }
    }
}

// MARK: - Readings

/// A measurement: a number and, separately, the unit it is measured in.
///
/// "4.31 GB" is not one word. Setting the unit a step down and a shade back
/// lets a column of readings be scanned by their numbers, which is the only
/// part that differs between rows.
public struct Reading: View {
    public enum Emphasis {
        /// The headline number on a stat card. `metric` 24.
        case metric
        /// A heading-sized reading: a category total, free space.
        case heading
        /// A row's own size. `labelNumeric` 12.
        case row
        /// A dense row or a legend. `captionNumeric` 11.
        case dense
    }

    /// What counts as a unit worth setting apart.
    ///
    /// The split has to be conservative, because not every value with a space
    /// in it is a measurement: "M5 Max" and "5 小时 3 分" are single readings
    /// and setting their tail as a unit would be nonsense. Only a recognised
    /// unit gets demoted; anything else stays one string.
    private static let knownUnits: Set<String> = [
        "B", "KB", "MB", "GB", "TB", "PB",
        "B/s", "KB/s", "MB/s", "GB/s", "TB/s"
    ]

    private let value: String
    private let unit: String
    private let emphasis: Emphasis
    private let tint: Color

    public init(_ formatted: String, emphasis: Emphasis = .row, tint: Color = Palette.ink) {
        let split = Reading.parts(formatted)
        self.value = split.value
        self.unit = split.unit
        self.emphasis = emphasis
        self.tint = tint
    }

    /// Divides a formatted reading into the quantity and the unit it is
    /// measured in, or leaves it whole when the tail is not a unit.
    public static func parts(_ formatted: String) -> (value: String, unit: String) {
        guard let space = formatted.lastIndex(of: " ") else { return (formatted, "") }
        let tail = String(formatted[formatted.index(after: space)...])
        guard knownUnits.contains(tail) else { return (formatted, "") }
        return (String(formatted[formatted.startIndex..<space]), tail)
    }

    public init(bytes: Int64, emphasis: Emphasis = .row, tint: Color = Palette.ink) {
        self.init(Bytes.format(bytes), emphasis: emphasis, tint: tint)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(value)
                .font(valueFont)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(tint)
            if !unit.isEmpty {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .lineLimit(1)
    }

    private var valueFont: Font {
        switch emphasis {
        case .metric: return Typo.metric
        case .heading: return Typo.subheadNumeric
        case .row: return Typo.labelNumeric
        case .dense: return Typo.captionNumeric
        }
    }

    /// The unit is always a step down and a shade back. At `metric` the step
    /// is bigger, because 24 against 11 would read as a footnote rather than
    /// as the ruler the number is measured on.
    private var unitFont: Font {
        emphasis == .metric ? Typo.cardTitle : Typo.caption
    }
}

// MARK: - Search field

/// The app's one search control. It takes no size: the row it sits in gives
/// it one, which is what finally makes it the same height as its neighbours.
public struct SearchField: View {
    @Binding var text: String
    let prompt: String

    @Environment(\.rowControlHeight) private var height

    public init(text: Binding<String>, prompt: String) {
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .glyph(.control)
                .foregroundStyle(Palette.inkTertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.body)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .glyph(.control)
                        .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: height)
        .frame(maxWidth: Layout.searchWidth)
        .glassSurface(Capsule(style: .continuous), level: .interactive)
        .animation(Motion.hover, value: text.isEmpty)
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

    private let side: CGFloat = 16

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
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(state == .off ? AnyShapeStyle(Color.clear) : AnyShapeStyle(tint.gradient))
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(state == .off ? Palette.inkFaint : Color.clear, lineWidth: 1)
                if state == .on {
                    Image(systemName: "checkmark")
                        .glyph(.badge, weight: .black)
                        .foregroundStyle(Palette.onAccent)
                } else if state == .mixed {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Palette.onAccent)
                        .frame(width: 8, height: 2)
                }
            }
            .frame(width: side, height: side)
            // Vertically the target is a full control tier; horizontally it
            // stays 16, because this column is the first term in the row's
            // title edge (16 + 12 + 32 + 12 = 72 from the row's inner edge)
            // and widening it moves every list title in the app.
            .frame(width: side, height: Control.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .actionEnabled(enabled)
        .animation(Motion.state, value: state)
        .accessibilityAddTraits(state == .on ? [.isSelected] : [])
    }
}

/// The width a checkbox would take, for rows in lists that have no selection.
///
/// It looks like nothing and it is the reason a row title starts in the same
/// place whether or not its list can be selected — which matters most on a
/// page whose two tabs differ in exactly that, where the titles would
/// otherwise shift 28pt sideways as you switch.
public struct RowLeadingSpacer: View {
    public init() {}

    public var body: some View {
        Color.clear.frame(width: 16, height: Control.compact)
    }
}

// MARK: - Capacity bar

/// A slim horizontal fill. Two heights: 4 inside a card or a row, 6 where it
/// is the thing you are meant to read.
public struct CapacityBar: View {
    public enum Weight {
        case thin, thick

        var height: CGFloat { self == .thin ? 4 : 6 }
    }

    private let fraction: Double
    private let tint: Color
    private let weight: Weight

    public init(fraction: Double, tint: Color = Palette.aqua, weight: Weight = .thin) {
        self.fraction = min(1, max(0, fraction))
        self.tint = tint
        self.weight = weight
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Palette.wellFill)
                Capsule(style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: max(fraction > 0 ? weight.height : 0, geo.size.width * fraction))
            }
        }
        .frame(height: weight.height)
        .animation(Motion.settle, value: fraction)
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
                .glyph(.feature)
                .foregroundStyle(Palette.aqua)
            Text(title)
                .font(Typo.cardTitle)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(Typo.labelPlain)
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
            .font(Typo.overline)
            .tracking(0.6)
            .foregroundStyle(Palette.inkTertiary)
    }
}

// MARK: - Stat card

/// The one card used for every headline number in the app.
///
/// Every slot here is *reserved* whether or not it is filled, and the page
/// declares the slot heights once for the whole grid, so a row of these is
/// equal-height by construction rather than by luck.
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

                Reading(value, emphasis: .metric)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(height: 29, alignment: .leading)

                // A clear floor holds each slot's height even when what goes
                // in it is an `EmptyView` — and the content rides in an
                // *overlay* rather than a `ZStack`, which is what keeps the
                // card inside its column. A `ZStack` is as wide as its widest
                // child: measured in a 249pt column, the memory legend made
                // the card 296pt and spilled into both gutters. An overlay
                // never contributes to layout.
                if let chartHeight {
                    Color.clear
                        .frame(height: chartHeight)
                        .overlay { chart }
                }

                if let extraHeight {
                    Color.clear
                        .frame(height: extraHeight)
                        // Top, not centre: the slot is tall enough for a
                        // legend that wraps to two lines, and a one-line
                        // legend centred in it would sit lower than a wrapped
                        // one on the card beside it.
                        .overlay(alignment: .top) { extra }
                }

                if reservesProgress {
                    Color.clear
                        .frame(height: CapacityBar.Weight.thin.height)
                        .overlay {
                            if let progress {
                                CapacityBar(fraction: progress, tint: tint)
                            }
                        }
                }

                Text(detail)
                    .font(Typo.caption)
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
                .glyph(.caption)
                .foregroundStyle(tint)
            Text(label)
                .font(Typo.label)
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge {
                Badge(badge, style: .tinted(tint))
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(height: 17)
    }
}

/// A row of stat cards on explicit, equal-width columns.
///
/// The ragged rows this replaces were not a spacing bug: `GridItem(.adaptive)`
/// fits as many columns as the container allows and leaves the rest empty, so
/// four cards got three columns and landed as a row of three with one card
/// stranded underneath. Counting the cards fixes both that and the uneven
/// split. Top alignment is the other half — without it a shorter card is
/// centred against a taller neighbour.
public struct StatCardGrid<Content: View>: View {
    private let minimum: CGFloat
    private let spacing: CGFloat
    private let content: Content

    /// Zero until the first layout pass reports a width; one column is the
    /// honest answer for an unknown container and settles in the same frame.
    @State private var width: CGFloat = 0

    public init(
        minimum: CGFloat = Layout.statCardMinimum,
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
        // collapsing to a single file.
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
    private let label: String?
    private let value: String?

    public init(_ color: Color, _ label: String?, value: String? = nil) {
        self.color = color
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(spacing: Space.xs) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color)
                .frame(width: 7, height: 7)
            if let label {
                Text(label)
                    .font(Typo.overline)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }
            if let value {
                Text(value)
                    .font(Typo.overline)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    // The reading is the point of the legend; if the row runs
                    // out of room the key gives way first, never the number.
                    .layoutPriority(1)
            }
        }
        // Deliberately not `.fixedSize()`. A legend that refuses to compress
        // does not stay legible — it drags its card out of the grid.
    }
}

/// A row of legend entries that gives way instead of pushing its card wider.
///
/// Measured in both languages: the memory card's three entries want 287pt in
/// English and 252pt in Chinese, and the grid gives a card 204–244pt inside
/// its padding. So the row has four forms — normal gutters, tight gutters,
/// two lines, and swatch with reading only — and takes the first that fits.
public struct LegendRow: View {
    public struct Entry: Identifiable {
        public let id: String
        fileprivate let color: Color
        fileprivate let label: String
        fileprivate let value: String?

        public init(_ color: Color, _ label: String, value: String? = nil) {
            self.id = label
            self.color = color
            self.label = label
            self.value = value
        }
    }

    private let entries: [Entry]

    public init(_ entries: [Entry]) {
        self.entries = entries
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            row(spacing: Space.md, showsLabels: true)
            row(spacing: Space.sm, showsLabels: true)
            wrapped
            row(spacing: Space.sm, showsLabels: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(spacing: CGFloat, showsLabels: Bool) -> some View {
        HStack(spacing: spacing) {
            ForEach(entries) { entry in
                LegendDot(entry.color, showsLabels ? entry.label : nil, value: entry.value)
            }
        }
    }

    /// The same entries over two lines, the first taking the ceiling half.
    private var wrapped: some View {
        let split = (entries.count + 1) / 2
        return VStack(alignment: .leading, spacing: 2) {
            line(Array(entries.prefix(split)))
            line(Array(entries.dropFirst(split)))
        }
    }

    private func line(_ entries: [Entry]) -> some View {
        HStack(spacing: Space.sm) {
            ForEach(entries) { entry in
                LegendDot(entry.color, entry.label, value: entry.value)
            }
        }
    }
}

// MARK: - Segmented bar

/// A stacked bar whose segments each carry their own colour, for a total made
/// of distinguishable parts.
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
    private let height: CGFloat = 6

    public init(segments: [Segment]) {
        self.segments = segments
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
        .animation(Motion.settle, value: segments)
    }
}

// MARK: - Sparkline

/// One or more series over a shared time window.
///
/// Series are normalised against the *combined* peak so their relative heights
/// stay honest; normalising each against its own peak would draw a trickle of
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

/// Hover and press feedback for list rows. One hover value for the app: 6%.
public struct RowInteraction: ViewModifier {
    var radius: CGFloat = Radius.card
    var tint: Color = Palette.aqua

    @State private var hovering = false
    @State private var pressed = false

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(hovering ? 0.06 : 0))
            }
            .scaleEffect(pressed ? 0.992 : 1)
            .animation(Motion.hover, value: hovering)
            .animation(Motion.press, value: pressed)
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

    /// The selected appearance every list in the app shares: an 8% wash and a
    /// 1.5pt edge, so a long list still reads once it is scrolled away from
    /// the checkboxes.
    public func rowSelection(_ selected: Bool, hovering: Bool = false, radius: CGFloat = Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            shape.fill(Palette.aqua.opacity(selected ? 0.08 : (hovering ? 0.06 : 0)))
        }
        .overlay {
            shape.strokeBorder(Palette.aqua.opacity(selected ? 0.5 : 0), lineWidth: 1.5)
        }
        .animation(Motion.state, value: selected)
        .animation(Motion.hover, value: hovering)
    }
}

// MARK: - Selection bar

/// The persistent bar above a list of tickable things.
///
/// It is always on screen. Revealing it only once something was selected read
/// as *no* batch feature at all — nothing on the page said the operation
/// existed. It also now carries the total it is about to act on: the size of
/// a batch is the thing you want to know before you run one, not after.
public struct SelectionBar<Actions: View>: View {
    private let selectedCount: Int
    private let totalCount: Int
    private let allSelected: Bool
    private let impact: String?
    private let onToggleAll: () -> Void
    private let actions: Actions

    public init(
        selectedCount: Int,
        totalCount: Int,
        allSelected: Bool,
        impact: String? = nil,
        onToggleAll: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.allSelected = allSelected
        self.impact = impact
        self.onToggleAll = onToggleAll
        self.actions = actions()
    }

    public var body: some View {
        HStack(spacing: Space.md) {
            TriStateBox(
                state: allSelected ? .on : (selectedCount > 0 ? .mixed : .off),
                action: onToggleAll
            )

            Button(allSelected ? t("取消全选", "Deselect all") : t("全选", "Select all"), action: onToggleAll)
                .buttonStyle(TextButtonStyle())

            HStack(spacing: Space.xs) {
                Text(t("已选", "Selected"))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                Text("\(selectedCount)")
                    .font(Typo.bodyNumeric)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(selectedCount > 0 ? Palette.ink : Palette.inkTertiary)
                Text("/ \(totalCount)")
                    .font(Typo.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkFaint)
            }

            if let impact, selectedCount > 0 {
                Text("·")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkFaint)
                Reading(impact, emphasis: .dense, tint: Palette.inkSecondary)
                    .transition(.opacity)
            }

            Spacer(minLength: Space.sm)

            actions
        }
        .imposesControlHeight(Control.standard)
        .animation(Motion.state, value: selectedCount)
        .padding(.horizontal, Space.md)
        .frame(height: Layout.actionBar)
        .glassPanel(radius: Radius.row)
    }
}
