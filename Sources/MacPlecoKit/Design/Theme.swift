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

    // Structure.
    public static let hairline = Color.veil(0.10, light: 0.09)
    public static let hairlineStrong = Color.veil(0.18, light: 0.14)
    public static let wellFill = Color.veil(0.05, light: 0.045)

    /// The ambient background for the whole window: a deep gradient with two
    /// soft light sources, as if lit from above and from one side.
    public static var tankGradient: LinearGradient {
        LinearGradient(
            colors: [shallow, deep, abyss],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The accent sweep used on the primary action and the depth ring.
    public static var aquaSweep: LinearGradient {
        LinearGradient(
            colors: [aquaBright, aqua, aquaDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Metrics

/// Layout constants. Radii are picked so that a child nested inside a parent
/// with `Radius.panel` padding by `Space.md` lands on `Radius.card`, keeping
/// corners concentric rather than merely rounded.
public enum Radius {
    public static let pill: CGFloat = 999
    public static let panel: CGFloat = 22
    public static let card: CGFloat = 16
    public static let row: CGFloat = 12
    public static let chip: CGFloat = 8
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

// MARK: - Type ramp

/// Every piece of text in the app picks one of these roles.
///
/// Before this existed the app used **27 distinct point sizes**, eight of them
/// packed between 9 and 13.5pt — a range where a half-point difference is
/// invisible as hierarchy and visible only as sloppiness. `SelectionBar` alone
/// set four adjacent labels in one row at 12, 11.5, 12.5 and 11pt. Nobody can
/// read that as structure.
///
/// The ramp below is eleven steps. Each step is at least a whole point from
/// its neighbours, and each role fixes size *and* weight *and* typeface design
/// together, so choosing how to set a piece of text is one decision instead of
/// three. Emphasis inside a role is a weight step (`.weight(.semibold)`), never
/// a new size.
///
/// The ordering claim the ramp makes about this app: a page's own name is
/// orientation, not the message. `pageTitle` (20) therefore sits *below*
/// `metric` (24) — the number the user came for outranks the label on the door.
public enum Typo {

    /// The raw steps, for the few places that need a number rather than a
    /// `Font` — icon sizing that has to match adjacent text, mostly.
    public enum Step {
        /// Paths, chart axis ticks, sort glyphs. Text that is present for
        /// reference, not for reading.
        public static let micro: CGFloat = 9
        /// Badges and section overlines. Always semibold, usually tracked.
        public static let overline: CGFloat = 10
        /// Metadata, hints, footnotes.
        public static let caption: CGFloat = 11
        /// Control labels and secondary row text.
        public static let label: CGFloat = 12
        /// Prose. The page's supporting sentence lives here.
        public static let body: CGFloat = 13
        /// Card titles, primary row text, button labels.
        public static let subhead: CGFloat = 15
        /// The heading of a card that owns a whole block.
        public static let cardTitle: CGFloat = 17
        /// The page's own name.
        public static let pageTitle: CGFloat = 20
        /// A stat card's value.
        public static let metric: CGFloat = 24
        /// The one sentence a page leads with, when it has one.
        public static let feature: CGFloat = 30
        /// The single largest number on a page. Never more than one.
        public static let hero: CGFloat = 44
    }

    public static let micro = Font.system(size: Step.micro)
    public static let microMono = Font.system(size: Step.micro, design: .monospaced)
    /// Uppercase section labels and badges. Tracking is applied by the
    /// components that use it, since it only suits capitals.
    public static let overline = Font.system(size: Step.overline, weight: .semibold)
    public static let caption = Font.system(size: Step.caption)
    public static let captionStrong = Font.system(size: Step.caption, weight: .medium)
    public static let label = Font.system(size: Step.label, weight: .medium)
    public static let labelPlain = Font.system(size: Step.label)
    public static let labelNumeric = Font.system(size: Step.label, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: Step.body)
    public static let bodyStrong = Font.system(size: Step.body, weight: .medium)
    public static let subhead = Font.system(size: Step.subhead, weight: .semibold)
    public static let subheadPlain = Font.system(size: Step.subhead)
    public static let cardTitle = Font.system(size: Step.cardTitle, weight: .semibold, design: .rounded)
    public static let pageTitle = Font.system(size: Step.pageTitle, weight: .bold, design: .rounded)
    public static let metric = Font.system(size: Step.metric, weight: .bold, design: .rounded)
    public static let feature = Font.system(size: Step.feature, weight: .bold, design: .rounded)
    public static let hero = Font.system(size: Step.hero, weight: .bold, design: .rounded)
}
