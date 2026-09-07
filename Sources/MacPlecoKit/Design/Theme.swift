import SwiftUI
import AppKit

// MARK: - Color construction

extension Color {
    /// Builds a colour from a 0xRRGGBB literal in the sRGB space.
    init(srgb hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// A colour that resolves differently in light and dark appearance.
    ///
    /// Using AppKit's dynamic provider (rather than reading `\.colorScheme` in
    /// every view) means the palette adapts even inside `Canvas`, popovers and
    /// menu-bar windows, which do not always inherit the environment.
    static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightOpacity: Double = 1,
        darkOpacity: Double = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            let alpha = isDark ? darkOpacity : lightOpacity
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: CGFloat(alpha)
            )
        })
    }

    /// A neutral overlay that flips polarity between appearances — white veils
    /// on dark backgrounds, black veils on light ones.
    static func veil(_ darkOpacity: Double, light lightOpacity: Double? = nil) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            if isDark {
                return NSColor(white: 1.0, alpha: CGFloat(darkOpacity))
            }
            return NSColor(white: 0.0, alpha: CGFloat(lightOpacity ?? darkOpacity * 0.85))
        })
    }
}

// MARK: - Palette

/// The "Deep Water" palette.
///
/// The product metaphor is an aquarium: the window is deep, softly lit water
/// and every panel is a pane of glass suspended in it. Aqua is the only
/// saturated hue used for affirmative actions, which keeps "safe to remove"
/// instantly readable; amber and coral are rationed for caution and for
/// genuinely irreversible operations.
public enum Palette {

    // Window ground — a vertical descent from shallow to deep water.
    //
    // The light values are deliberately tinted rather than near-white: the
    // first build's light mode was so pale that glass had nothing to refract
    // and the whole interface read as flat paper.
    public static let abyss = Color.adaptive(light: 0xD3E2F0, dark: 0x050B14)
    public static let deep = Color.adaptive(light: 0xE2EDF7, dark: 0x0A1626)
    public static let shallow = Color.adaptive(light: 0xEFF5FA, dark: 0x102437)

    // The four drifting colour fields behind everything (see AmbientBackground).
    // Opacity is baked in so the Canvas can fill them directly.
    public static let auroraAqua = Color.adaptive(
        light: 0x53D6C1, dark: 0x0E6B60, lightOpacity: 0.42, darkOpacity: 0.42
    )
    public static let auroraSky = Color.adaptive(
        light: 0x74B2F2, dark: 0x1B3F78, lightOpacity: 0.40, darkOpacity: 0.46
    )
    public static let auroraViolet = Color.adaptive(
        light: 0xA495EC, dark: 0x33306B, lightOpacity: 0.30, darkOpacity: 0.40
    )
    public static let auroraWarm = Color.adaptive(
        light: 0xF4C6A4, dark: 0x14586E, lightOpacity: 0.26, darkOpacity: 0.36
    )

    // Brand accents.
    /// Clean water. Reserved for affirmative, safe, "go" meaning.
    public static let aqua = Color.adaptive(light: 0x0B8F84, dark: 0x38D9C4)
    public static let aquaBright = Color.adaptive(light: 0x11B3A4, dark: 0x62F0DA)
    public static let aquaDeep = Color.adaptive(light: 0x066A62, dark: 0x1B9C93)
    /// The current running through the tank. Secondary/informational.
    public static let flow = Color.adaptive(light: 0x1F6BD4, dark: 0x5AA6F8)

    // Semantic.
    public static let caution = Color.adaptive(light: 0xB0700A, dark: 0xF3BC5C)
    public static let danger = Color.adaptive(light: 0xCE3B36, dark: 0xFF7A72)
    public static let positive = Color.adaptive(light: 0x1C8A4E, dark: 0x4ADE80)

    // Chart series.
    //
    // Picked to differ in lightness as well as hue, so two series stay
    // separable in light mode, in dark mode, and for the most common forms of
    // colour-vision deficiency — where teal against blue would not be.
    public static let chartTeal = Color.adaptive(light: 0x0B8F84, dark: 0x38D9C4)
    public static let chartViolet = Color.adaptive(light: 0x6D3BD1, dark: 0xB794F6)
    public static let chartAmber = Color.adaptive(light: 0xB4530A, dark: 0xFBA94C)
    public static let chartBlue = Color.adaptive(light: 0x1F6BD4, dark: 0x5AA6F8)

    // Treemap tiles.
    //
    // A tile's area already says how big it is, so colour is free to say
    // *which* thing it is: ten muted folder hues instead of one ramp that
    // repeated the size in a second channel. The order is deliberate —
    // neighbouring indices sit far apart on the wheel, and because tiles are
    // laid out largest first, index adjacency is visual adjacency.
    public static let folderTones: [Color] = [
        .adaptive(light: 0x0F8A80, dark: 0x17A093),
        .adaptive(light: 0xB0603C, dark: 0xC4724A),
        .adaptive(light: 0x5A5FB5, dark: 0x6E74CC),
        .adaptive(light: 0x5C8A33, dark: 0x6DA33F),
        .adaptive(light: 0xB25070, dark: 0xC46184),
        .adaptive(light: 0x17809A, dark: 0x1F97B4),
        .adaptive(light: 0xA2762A, dark: 0xB98A33),
        .adaptive(light: 0x8B5AA8, dark: 0xA06CBF),
        .adaptive(light: 0x2E8F63, dark: 0x37A876),
        .adaptive(light: 0x2A6FB8, dark: 0x3684D1)
    ]

    /// Loose files stay out of the folder palette entirely, in one desaturated
    /// warm tone: "one huge file" and "a folder of many things" must never
    /// look like each other. Red is not used here — it stays reserved for
    /// danger, and a large file is not dangerous.
    public static let fileTone = Color.adaptive(light: 0x937A52, dark: 0xA68A5E)

    /// The consolidated long tail is deliberately colourless. It is not one
    /// thing, so it should not look like one.
    public static let tailTone = Color.adaptive(light: 0x6B7580, dark: 0x77828E)

    // Text.
    public static let ink = Color.adaptive(light: 0x0B1826, dark: 0xF3F8FC)
    public static let inkSecondary = Color.veil(0.66, light: 0.62)
    public static let inkTertiary = Color.veil(0.40, light: 0.42)
    public static let inkFaint = Color.veil(0.24, light: 0.26)

    /// The fill under the app's one affirmative action, and the glyph colour
    /// that goes on top of any saturated accent.
    ///
    /// `aquaSweep` cannot carry text. Measured against this palette, white on
    /// its stops is 2.62:1 at the light end in light appearance and 1.40:1 in
    /// dark — the "Start cleaning" button, the single loudest thing in the
    /// app, was less readable than the pink Uninstall button this standard was
    /// written to fix. The sweep is still right for the depth ring and the
    /// capacity bars, which carry no text.
    ///
    /// So a filled control uses `goFill`, which goes *deep* in light
    /// appearance and stays bright in dark, and pairs with `onAccent` — white
    /// on the dark fills, near-black on the bright ones. Minimum measured
    /// contrast: 4.64:1 light, 5.68:1 dark.
    public static let goFillTop = Color.adaptive(light: 0x0A8378, dark: 0x62F0DA)
    public static let goFillMid = Color.adaptive(light: 0x077268, dark: 0x38D9C4)
    public static let goFillEnd = Color.adaptive(light: 0x055C54, dark: 0x1B9C93)

    /// Text and glyphs drawn on a saturated accent. Every accent in this
    /// palette is dark in light appearance and bright in dark appearance, so
    /// the legible foreground flips with them — one token covers aqua,
    /// caution, flow, positive and the chart hues (worst case 3.98:1 on light
    /// aqua, 7.53:1 in dark).
    public static let onAccent = Color.adaptive(light: 0xFFFFFF, dark: 0x061018)

    /// The only fill a destructive action is ever allowed, and only on a
    /// confirmation surface. `danger` itself is a *text* colour: white on a
    /// 12% `danger` glass tint measures 2.6:1, which is why the old pink
    /// "Uninstall selected" button was unreadable. These two values carry
    /// white at 5.6:1 in light and 8.2:1 in dark.
    public static let dangerSolid = Color.adaptive(light: 0xC0342F, dark: 0x8F2C28)

    // Structure.
    public static let hairline = Color.veil(0.10, light: 0.09)
    public static let hairlineStrong = Color.veil(0.18, light: 0.14)
    public static let wellFill = Color.veil(0.05, light: 0.045)

    // Interactive glass, minimum legibility (see `GlassLevel.interactive`).
    //
    // On the pale "shallow water" ground, `.ultraThinMaterial` under a 0.5pt
    // hairline has almost no edge — the Overview's secondary button lost its
    // outline entirely. Anything clickable therefore sits on an opaque-enough
    // fill with a stroke at least 16%.
    public static let controlFill = Color.adaptive(
        light: 0xFFFFFF, dark: 0xE8F2FA, lightOpacity: 0.72, darkOpacity: 0.14
    )
    public static let controlStroke = Color.veil(0.24, light: 0.20)

    /// The ambient background for the whole window: a deep gradient with two
    /// soft light sources, as if lit from above and from one side.
    public static var tankGradient: LinearGradient {
        LinearGradient(
            colors: [shallow, deep, abyss],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The accent sweep. Decorative only: the depth ring, capacity fills and
    /// the treemap. Nothing legible is ever set on it — see `goFill`.
    public static var aquaSweep: LinearGradient {
        LinearGradient(
            colors: [aquaBright, aqua, aquaDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The sweep under a filled action, paired with `onAccent`.
    public static var goFill: LinearGradient {
        LinearGradient(
            colors: [goFillTop, goFillMid, goFillEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Metrics

/// Corner radii. A child nested inside a parent by `Space.md` lands on the
/// next token down, so corners stay concentric: 22 padded by 12 gives 8.
public enum Radius {
    public static let pill: CGFloat = 999
    public static let panel: CGFloat = 22
    public static let card: CGFloat = 16
    public static let row: CGFloat = 12
    public static let chip: CGFloat = 8
    /// Small squares: checkboxes, legend swatches, core bars.
    public static let control: CGFloat = 4
}

public enum Space {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let huge: CGFloat = 48
}

// MARK: - Control tiers

/// The height of anything clickable. There are four values and no others.
///
/// `standard` (28) is the default, and the reason is Chinese type. A Han
/// glyph has no ascender or descender — it fills the whole em — so 13pt text
/// in a 24pt capsule leaves 5.5pt above and below and reads as if it is
/// touching the edges, where the same capsule looks roomy around Latin text.
/// Copying Latin control heights is the single most common way a Chinese
/// interface ends up feeling cramped. The floor for vertical breathing room
/// is 7pt, which puts 13pt text in a 28pt control.
///
/// 28 is also `.controlSize(.large)` on macOS 26, so system pickers, menus
/// and toggles line up with our own controls without being resized by hand.
/// 44 is deliberately *not* the default: it is the iOS touch target, not a
/// macOS control height.
public enum Control {
    /// Row-internal actions and icon-button hit areas.
    public static let compact: CGFloat = 24
    /// The default. Filter rows, masthead slots, tabs, bar actions, sheet
    /// footers — around 90% of the controls in the app.
    public static let standard: CGFloat = 28
    /// A card's own main action: permission card, finished card, menu bar.
    public static let emphasis: CGFloat = 36
    /// At most one group per page. Never used for a destructive action.
    public static let hero: CGFloat = 44

    /// Vertical breathing room a control keeps around 13pt Chinese text.
    public static let minTextInset: CGFloat = 7

    /// Which system `ControlSize` renders closest to a given tier.
    public static func size(for height: CGFloat) -> ControlSize {
        if height >= emphasis { return .extraLarge }
        if height >= standard { return .large }
        return .small
    }

    /// The type role a control of this height uses. Size is not a free
    /// parameter at the call site: the tier picks it.
    public static func font(for height: CGFloat) -> Font {
        if height >= emphasis { return Typo.subhead }
        if height >= standard { return Typo.body }
        return Typo.label
    }

    /// The same role, when the label needs to read as an action rather than
    /// as running text (filled and outlined buttons at `standard`).
    public static func actionFont(for height: CGFloat) -> Font {
        if height >= emphasis { return Typo.subhead }
        if height >= standard { return Typo.bodyStrong }
        return Typo.label
    }

    public static func horizontalPadding(for height: CGFloat) -> CGFloat {
        if height >= hero { return Space.xl }
        if height >= emphasis { return 20 }
        if height >= standard { return 14 }
        return Space.md
    }

    public static func glyph(for height: CGFloat) -> Glyph {
        height >= emphasis ? .row : (height >= standard ? .control : .control)
    }
}

// MARK: - Glyphs

/// The point size of an SF Symbol. Icons used to borrow `Typo.Step`, which
/// tied a glyph's size to a text role it had nothing to do with.
public enum Glyph: CGFloat {
    /// Inside badges, sort chevrons, result lines.
    case badge = 9
    /// Page notes, stat card headers, icon buttons.
    case caption = 11
    /// Inside `standard` controls and the search field.
    case control = 13
    /// A row's leading symbol; inside `emphasis` and `hero` controls.
    case row = 15
    /// Scanning card, ledger strip.
    case card = 17
    /// Permission card, sheet header.
    case title = 20
    /// Empty and unreadable states.
    case feature = 30
}

extension View {
    /// Sets an SF Symbol at one of the seven glyph sizes. Pages use this
    /// instead of `.font(.system(size:))`, which CI rejects.
    public func glyph(_ size: Glyph, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size.rawValue, weight: weight))
    }
}

/// A square, tinted container for a symbol. Side and radius come as a pair
/// and cannot be separated — the app used to have five sizes (44/34/32/30/22)
/// against four radii (12/9/8/8/6) with no relationship between them. Here
/// radius is always side ÷ 3.6 rounded to a token.
public enum IconBox {
    /// Menu bar brand.
    case small
    /// The masthead brand mark — exactly as tall as the masthead band.
    case masthead
    /// Categories, banners, app icons in rows.
    case medium
    /// Sheet headers.
    case large

    public var side: CGFloat {
        switch self {
        case .small: return 24
        case .masthead: return 28
        case .medium: return 32
        case .large: return 44
        }
    }

    public var radius: CGFloat {
        switch self {
        case .small: return 6
        case .masthead, .medium: return Radius.chip
        case .large: return Radius.row
        }
    }

    public var glyph: Glyph {
        switch self {
        case .small: return .caption
        case .masthead, .medium: return .row
        case .large: return .title
        }
    }
}

// MARK: - Motion

/// Six durations. The app had thirteen, several of them a hundredth of a
/// second apart, which is a difference nobody can perceive as intent.
public enum Motion {
    public static let press = Animation.snappy(duration: 0.16)
    public static let hover = Animation.smooth(duration: 0.20)
    public static let state = Animation.smooth(duration: 0.25)
    public static let reveal = Animation.smooth(duration: 0.30)
    public static let settle = Animation.smooth(duration: 0.50)
    public static let enter = Animation.smooth(duration: 0.55)
    public static let enterStagger: Double = 0.06

    /// Opacity of a disabled control. One value, everywhere.
    public static let disabledOpacity: Double = 0.4
    /// Opacity of a pressed control. One value, everywhere.
    public static let pressedOpacity: Double = 0.8
}

// MARK: - Layout

/// Fixed measurements that belong to the layout rather than to a component.
/// Pages read these instead of writing numbers, which is what lets CI reject
/// a literal height in `Features/`.
public enum Layout {
    /// The content column's ceiling, on every page.
    public static let contentWidth: CGFloat = 1140
    /// One minimum for every stat grid in the app (it used to be 224 on
    /// Overview and 236 on Monitor, so the two pages wrapped at different
    /// window widths).
    public static let statCardMinimum: CGFloat = 224
    /// A row's leading symbol column.
    public static let rowIcon: CGFloat = 32
    /// Every numeric column in a list, measured against Chinese labels.
    public static let valueColumn: CGFloat = 80
    /// Every trailing action cluster in a list.
    public static let actionColumn: CGFloat = 96
    /// The one search field width.
    public static let searchWidth: CGFloat = 260
    /// Where a masthead's shared baseline sits above the band's bottom edge.
    public static let mastheadBaseline: CGFloat = 7
    /// The space treemap.
    public static let treemap: CGFloat = 500
    /// Standard list row, and the same value its skeleton placeholder uses.
    public static let standardRow: CGFloat = 56
    /// A standard row carrying a second line of path.
    public static let tallRow: CGFloat = 72
    /// Compact table row: clean items, processes, sheet leftovers.
    public static let compactRow: CGFloat = 40
    /// A group header row (clean categories).
    public static let groupRow: CGFloat = 64
    /// A bar of text only, and a bar carrying a `standard` control.
    public static let textBar: CGFloat = 40
    public static let actionBar: CGFloat = 48
    /// Per-core load strip in Monitor.
    public static let coreStrip = CGSize(width: 260, height: 26)
}

// MARK: - Type ramp

/// Every piece of text in the app picks one of these roles.
///
/// Before this existed the app used **27 distinct point sizes**, eight of them
/// packed between 9 and 13.5pt — a range where a half-point difference is
/// invisible as hierarchy and visible only as sloppiness. `SelectionBar` alone
/// set four adjacent labels in one row at 12, 11.5, 12.5 and 11pt.
///
/// Each role fixes size *and* weight *and* typeface design together, so
/// choosing how to set a piece of text is one decision instead of three.
/// Emphasis inside a role is a weight step, never a new size.
///
/// Chinese sets the weight ceiling: PingFang's `bold` smears at small sizes,
/// so Han text stops at `semibold` and `bold` is reserved for rounded numerals
/// and the page title. Nothing Chinese is ever `light`, `thin`, or tracked.
///
/// The ordering claim the ramp makes about this app: a page's own name is
/// orientation, not the message. `pageTitle` (20) therefore sits *below*
/// `metric` (24) — the number the user came for outranks the label on the door.
public enum Typo {

    /// The raw steps. Deliberately **internal**: a page that can reach a
    /// number can invent a forty-first size combination, and 108 call sites
    /// had done exactly that. Roles are the public surface.
    enum Step {
        static let micro: CGFloat = 9
        static let overline: CGFloat = 10
        static let caption: CGFloat = 11
        static let label: CGFloat = 12
        static let body: CGFloat = 13
        static let subhead: CGFloat = 15
        static let cardTitle: CGFloat = 17
        static let pageTitle: CGFloat = 20
        static let metric: CGFloat = 24
        static let feature: CGFloat = 30
        static let hero: CGFloat = 44
    }

    /// The single largest number on a page. Never more than one.
    public static let hero = Font.system(size: Step.hero, weight: .bold, design: .rounded)
    /// The one sentence a page leads with, when it has one.
    public static let feature = Font.system(size: Step.feature, weight: .bold, design: .rounded)
    /// A stat card's value. Larger than the page title, on purpose.
    public static let metric = Font.system(size: Step.metric, weight: .bold, design: .rounded)
    /// The page's own name. `Masthead` only.
    public static let pageTitle = Font.system(size: Step.pageTitle, weight: .bold, design: .rounded)
    /// Sheet and empty-state titles.
    public static let cardTitle = Font.system(size: Step.cardTitle, weight: .semibold, design: .rounded)

    /// Group headings, `emphasis`/`hero` button labels, and the brand wordmark.
    public static let subhead = Font.system(size: Step.subhead, weight: .semibold)
    /// Sidebar destinations. The one place 15pt `medium` is right: the system
    /// draws the row, and semibold there would out-shout the page title beside
    /// it in the next column.
    public static let sidebarItem = Font.system(size: Step.subhead, weight: .medium)
    /// Plain running text at heading size.
    public static let subheadPlain = Font.system(size: Step.subhead)
    /// A heading-sized reading: category size, large file size, free space.
    public static let subheadNumeric = Font.system(size: Step.subhead, weight: .semibold, design: .rounded)

    /// Prose, and every `standard` control's label including toggle labels.
    public static let body = Font.system(size: Step.body)
    /// Standard row titles: app names, task names, file names.
    public static let bodyStrong = Font.system(size: Step.body, weight: .semibold)
    /// Selection counts and sheet totals.
    public static let bodyNumeric = Font.system(size: Step.body, weight: .semibold, design: .rounded)

    /// `compact` button labels, text buttons, compact row titles, stat labels.
    public static let label = Font.system(size: Step.label, weight: .medium)
    /// Secondary body text inside a row; empty-state copy.
    public static let labelPlain = Font.system(size: Step.label)
    /// A row's own size reading.
    public static let labelNumeric = Font.system(size: Step.label, weight: .semibold, design: .rounded)

    /// Metadata, notes, status, footnotes, timestamps, and units.
    public static let caption = Font.system(size: Step.caption)
    /// The label inside a well.
    public static let captionStrong = Font.system(size: Step.caption, weight: .medium)
    /// Readings inside dense rows and legends.
    public static let captionNumeric = Font.system(size: Step.caption, design: .rounded)

    /// Section labels, table headers, badge text, legend keys. Tracking is
    /// applied by the components that use it, since it only suits capitals.
    public static let overline = Font.system(size: Step.overline, weight: .semibold)
    /// Compact badges, result lines, warning lines.
    public static let tag = Font.system(size: Step.micro, weight: .semibold)
    /// Sort chevrons and axis ticks.
    public static let micro = Font.system(size: Step.micro)
    /// Paths and PIDs.
    public static let microMono = Font.system(size: Step.micro, design: .monospaced)
}
