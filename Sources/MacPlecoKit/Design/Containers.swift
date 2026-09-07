import SwiftUI

// Containers impose size; children do not accept it.
//
// This is the standard's first principle, and it exists because consistency
// kept failing even where there was only one implementation to be consistent
// with. `SearchField` is the app's single search control, and it still stood
// 7pt taller than the popup menu beside it — because nothing said the two
// were neighbours. A token cannot say that. A container can.
//
// So `FilterRow`, `Masthead` and `PageTabs` set the height, the type role and
// the system control size for everything inside them, and the controls
// themselves take no size parameter at all. A page cannot write three
// different heights on one line, because a page never writes a height.

// MARK: - Imposed metrics

private struct RowControlHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = Control.standard
}

extension EnvironmentValues {
    /// The height the surrounding container has imposed on its controls.
    var rowControlHeight: CGFloat {
        get { self[RowControlHeightKey.self] }
        set { self[RowControlHeightKey.self] = newValue }
    }
}

extension View {
    /// Applies a control tier to everything inside: our own controls read the
    /// value from the environment, system controls follow `controlSize`.
    func imposesControlHeight(_ height: CGFloat) -> some View {
        environment(\.rowControlHeight, height)
            .controlSize(Control.size(for: height))
            .font(Control.font(for: height))
    }
}

// MARK: - Choices

/// An enum that can be offered as a segmented choice. Every picker in the app
/// is one of these, so they all render at one size through one component.
public protocol TitledChoice: Hashable, Identifiable, CaseIterable {
    var title: String { get }
}

/// A segmented picker sized by its container rather than by its call site.
public struct SegmentedChoice<Value: TitledChoice>: View where Value.AllCases: RandomAccessCollection {
    @Binding private var selection: Value
    private let help: String

    @Environment(\.rowControlHeight) private var height

    public init(_ selection: Binding<Value>, help: String = "") {
        self._selection = selection
        self.help = help
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(Value.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .frame(height: height)
        .modifier(OptionalHelp(text: help))
    }
}

/// A pop-up menu, same contract.
public struct MenuChoice<Value: TitledChoice>: View where Value.AllCases: RandomAccessCollection {
    @Binding private var selection: Value
    private let width: CGFloat

    @Environment(\.rowControlHeight) private var height

    public init(_ selection: Binding<Value>, width: CGFloat = 140) {
        self._selection = selection
        self.width = width
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(Value.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: width, height: height)
    }
}

/// A switch whose label is `body` 13 like every other label on its row, and
/// whose box is centred in the row's height rather than setting it.
public struct ChoiceToggle: View {
    @Binding private var isOn: Bool
    private let title: String
    private let tint: Color

    @Environment(\.rowControlHeight) private var height

    public init(_ title: String, isOn: Binding<Bool>, tint: Color = Palette.aqua) {
        self.title = title
        self._isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(Typo.body)
                .foregroundStyle(Palette.inkSecondary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(tint)
        .frame(height: height)
    }
}

private struct OptionalHelp: ViewModifier {
    let text: String
    func body(content: Content) -> some View {
        if text.isEmpty { content } else { content.help(text) }
    }
}

// MARK: - Filter row

/// The row of controls that narrows a list: search, sort, scope, a status
/// reading. One height, one type size, no exceptions.
///
/// What it replaces, measured: a 31pt search field at 12pt beside a 24pt
/// popup at 13pt beside a 24pt mini switch at 11pt — three heights and three
/// sizes on one line, which is what made the Apps page look assembled from
/// spare parts.
public struct FilterRow<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Space.md) {
            content
        }
        .frame(height: Control.standard)
        .imposesControlHeight(Control.standard)
    }
}

// MARK: - Masthead

/// The band a page opens with, shared by the sidebar and the content column.
///
/// Both columns draw a band 28pt tall starting 12pt under the title bar, and
/// every piece of text in either one sits on **one baseline**, 7pt above the
/// band's bottom edge.
///
/// The baseline, not the box, is what has to match. v1.0 of this standard
/// asked for equal frame centres, which is right for Latin and wrong here:
/// Han glyphs fill the em box with no ascender or descender, so two Chinese
/// words at 20pt and 15pt centred in their own frames still sit visibly off
/// one another. Aligning the baselines puts them on the same optical line at
/// any pair of sizes, in either language.
public struct Masthead<Trailing: View>: View {
    private let title: String
    private let trailing: Trailing

    public init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        MastheadBand {
            Text(title)
                .font(Typo.pageTitle)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Space.md)
            // Exactly one control, and never navigation. Tabs used to live
            // here, which forced the slot to hold both a 24pt segmented
            // control and a 32pt button, so its height — and the position of
            // everything under it — changed from page to page.
            trailing
                .imposesControlHeight(Control.standard)
                .mastheadSlot()
        }
    }
}

/// The sidebar's half of the same band: a 28pt mark and the wordmark, on the
/// content column's baseline.
///
/// The wordmark is deliberately quieter than it was — `subhead` in
/// `inkSecondary` rather than 17pt bold ink. The app's name is not a heading;
/// it is the label on the window, and it was competing with the name of the
/// page you are actually looking at.
public struct BrandMasthead: View {
    private let title: String
    private let symbol: String

    public init(_ title: String, symbol: String = "fish.fill") {
        self.title = title
        self.symbol = symbol
    }

    public var body: some View {
        MastheadBand {
            IconTile(symbol, box: .masthead, style: .brand)
                .mastheadSlot()
            Text(title)
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: 0)
        }
    }
}

/// The 28pt band itself: fixed height, fixed top inset, one shared baseline.
public struct MastheadBand<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            content
        }
        .alignmentGuide(.bottom) { $0[.firstTextBaseline] + Layout.mastheadBaseline }
        .frame(height: Control.standard, alignment: .bottom)
        .padding(.top, Space.md)
    }
}

extension View {
    /// Puts a non-text element — a control, an icon tile — in the band so
    /// that it fills the band exactly while still participating in the
    /// baseline alignment around it.
    public func mastheadSlot() -> some View {
        alignmentGuide(.firstTextBaseline) { $0[.bottom] - Layout.mastheadBaseline }
    }
}

// MARK: - Page tabs

/// Switching between two views of a page is navigation, and navigation
/// belongs to the content, not to the window chrome. These sit on the content
/// column's own left edge, directly above the list they switch.
public struct PageTabs<Value: TitledChoice>: View where Value.AllCases: RandomAccessCollection {
    @Binding private var selection: Value

    public init(_ selection: Binding<Value>) {
        self._selection = selection
    }

    public var body: some View {
        SegmentedChoice($selection)
            .imposesControlHeight(Control.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Icon tile

/// A symbol in a tinted square. Side and radius always travel together.
public struct IconTile: View {
    public enum Style {
        /// Tinted wash behind a tinted symbol.
        case tinted(Color)
        /// A quiet well behind a tertiary symbol.
        case neutral
        /// The brand gradient behind a white symbol.
        case brand
    }

    private let symbol: String
    private let box: IconBox
    private let style: Style

    public init(_ symbol: String, box: IconBox = .medium, style: Style = .tinted(Palette.aqua)) {
        self.symbol = symbol
        self.box = box
        self.style = style
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: box.radius, style: .continuous)
            .fill(fill)
            .frame(width: box.side, height: box.side)
            .overlay {
                Image(systemName: symbol)
                    .glyph(box.glyph, weight: .semibold)
                    .foregroundStyle(foreground)
            }
            .shadow(color: shadow, radius: 6, y: 2)
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .tinted(let color): return AnyShapeStyle(color.opacity(0.14))
        case .neutral: return AnyShapeStyle(Palette.wellFill)
        case .brand: return AnyShapeStyle(Palette.goFill)
        }
    }

    private var foreground: Color {
        switch style {
        case .tinted(let color): return color
        case .neutral: return Palette.inkTertiary
        case .brand: return Palette.onAccent
        }
    }

    private var shadow: Color {
        if case .brand = style { return Palette.aqua.opacity(0.35) }
        return .clear
    }
}
