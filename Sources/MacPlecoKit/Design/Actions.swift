import SwiftUI

// The visual grammar of destructive and reversible actions.
//
// The README opens by promising that the destructive button is not the
// loudest thing on the screen. The code did the opposite:
// `PrimaryButtonStyle(tint: Palette.danger)` painted "Uninstall selected" as
// the biggest filled block on the Apps page, and white text on a 12% danger
// glass tint measured about 2.6:1 — loud *and* hard to read.
//
// A `tint:` parameter cannot fix that, because a parameter is an invitation.
// So the call site no longer chooses a colour. It declares what the action
// *means*, and the form follows:
//
//   go          → filled. The only filled intent.
//   reversible  → outlined, neutral ink. A recoverable delete is not red.
//   destructive → outlined, danger. Never filled in a list or a toolbar.
//   confirm     → filled danger, and only inside a confirmation surface.
//
// Two rules fall out of this and are enforced below rather than documented:
// at most one filled block per surface, and `.confirm` is inert — it renders
// as an ordinary destructive outline — anywhere outside a sheet or alert
// that has opted in with `.confirmationSurface()`.

// MARK: - Intent

/// What an action means for the person who clicks it. Form and colour are
/// derived from this; there is no colour parameter.
public enum ActionIntent: Sendable {
    /// Open, refresh, cancel, close. Carries no consequence.
    case neutral
    /// Makes things better for the user *and* can be undone — the one intent
    /// allowed to be the loudest thing on a page. "Start cleaning" qualifies
    /// because everything it touches lands in the Trash.
    case go
    /// A delete that can be put back. Neutral ink, not red: colouring a
    /// recoverable action red teaches people to ignore red, and then there is
    /// no word left for the operations that really cannot be undone.
    case reversible
    /// Irreversible, proposed. Uninstall, erase, end process. Outlined
    /// wherever it appears in a list or a bar.
    case destructive
    /// Irreversible, confirmed. Only renders filled on a `.confirmationSurface()`
    /// — by then the user has stated their intent and nothing else on that
    /// surface competes with it.
    case confirm

    /// The colour this intent's *text* takes. Fills are decided separately;
    /// most intents never get one.
    var foreground: Color {
        switch self {
        case .neutral, .reversible: return Palette.ink
        // `dangerSolid` is deep in both appearances, so white is right on it
        // in both. `goFill` flips, so its foreground flips with it.
        case .confirm: return .white
        case .go: return Palette.onAccent
        case .destructive: return Palette.danger
        }
    }

    /// Whether this intent paints a filled block, given where it is drawn.
    func isFilled(onConfirmationSurface: Bool) -> Bool {
        switch self {
        case .go: return true
        case .confirm: return onConfirmationSurface
        default: return false
        }
    }

    /// A wash behind an outlined button, so a destructive proposal reads as
    /// warmer than a neutral one without becoming a block of colour. The 12%
    /// `glassSurface` tint lands it at roughly the 6% the standard asks for
    /// once the control fill underneath is accounted for.
    var outlineWash: Color? {
        switch self {
        case .destructive, .confirm: return Palette.danger
        default: return nil
        }
    }

    var outlineStroke: Color {
        switch self {
        case .destructive, .confirm: return Palette.danger.opacity(0.55)
        default: return Palette.controlStroke
        }
    }
}

// MARK: - Confirmation surface

private struct ConfirmationSurfaceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside a sheet or alert that exists to confirm one operation.
    var isConfirmationSurface: Bool {
        get { self[ConfirmationSurfaceKey.self] }
        set { self[ConfirmationSurfaceKey.self] = newValue }
    }
}

extension View {
    /// Marks a sheet or alert as the place where an irreversible action is
    /// confirmed. Only inside one of these does `.confirm` render filled.
    public func confirmationSurface() -> some View {
        environment(\.isConfirmationSurface, true)
    }
}

// MARK: - Button style

/// Every button in the app. Height comes from `Control`, form from the
/// intent, and the type role and padding from the height — none of the three
/// is a free parameter.
public struct ActionButtonStyle: ButtonStyle {
    private let intent: ActionIntent
    private let height: CGFloat
    private let wide: Bool

    @Environment(\.isConfirmationSurface) private var onConfirmationSurface

    public init(
        _ intent: ActionIntent = .neutral,
        height: CGFloat = Control.standard,
        wide: Bool = false
    ) {
        // A destructive action never gets the page's loudest size. The hero
        // tier exists for the one thing a page wants you to do.
        assert(
            !(height >= Control.hero && (intent == .destructive || intent == .confirm)),
            "hero is for the page's affirmative action; destructive tops out at emphasis"
        )
        self.intent = intent
        self.height = height
        self.wide = wide
    }

    public func makeBody(configuration: Configuration) -> some View {
        let filled = intent.isFilled(onConfirmationSurface: onConfirmationSurface)
        return configuration.label
            .font(Control.actionFont(for: height))
            .foregroundStyle(filled ? intent.foreground : outlinedForeground)
            .lineLimit(1)
            .padding(.horizontal, Control.horizontalPadding(for: height))
            .frame(height: height)
            .frame(maxWidth: wide ? .infinity : nil)
            .background { background(filled: filled) }
            .opacity(configuration.isPressed ? Motion.pressedOpacity : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Capsule(style: .continuous))
    }

    /// An outlined `.confirm` — one drawn outside a confirmation surface —
    /// falls back to the destructive treatment rather than silently becoming
    /// a neutral button.
    private var outlinedForeground: Color {
        intent == .confirm ? Palette.danger : intent.foreground
    }

    @ViewBuilder
    private func background(filled: Bool) -> some View {
        let shape = Capsule(style: .continuous)
        if filled {
            shape
                .fill(intent == .confirm
                      ? AnyShapeStyle(Palette.dangerSolid)
                      : AnyShapeStyle(Palette.goFill))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                        .blendMode(.plusLighter)
                }
                .shadow(
                    color: (intent == .confirm ? Palette.dangerSolid : Palette.goFillMid).opacity(0.30),
                    radius: 12, y: 4
                )
        } else {
            // `.interactive` carries the legibility floor (see `Glass.swift`):
            // an opaque-enough fill and a stroke of at least 16%, so the
            // outline is a real edge on the pale ground rather than a hint.
            // A destructive intent adds its own wash and a danger edge on top.
            Color.clear
                .glassSurface(shape, level: .interactive, tint: intent.outlineWash)
                .overlay {
                    if intent == .destructive || intent == .confirm {
                        shape.strokeBorder(intent.outlineStroke, lineWidth: 1)
                    }
                }
        }
    }
}

// MARK: - Text button

/// A button with no container, for actions that live inside a line of text:
/// "Select all", "Recommended", "Clear", "Quit".
public struct TextButtonStyle: ButtonStyle {
    public enum Weight {
        /// Something to click. `flow` is the app's only "this is a link" colour.
        case normal
        /// A weak action next to a stronger one: clear, reset, quit.
        case quiet
    }

    private let weight: Weight

    public init(_ weight: Weight = .normal) {
        self.weight = weight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.label)
            .foregroundStyle(weight == .normal ? Palette.flow : Palette.inkTertiary)
            .opacity(configuration.isPressed ? Motion.pressedOpacity : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - Icon button

/// A symbol with a 24×24 hit area. Secondary row actions only — a row's main
/// action is a labelled button and is always visible.
public struct IconButton: View {
    private let symbol: String
    private let tint: Color
    private let help: String
    private let action: () -> Void

    public init(
        _ symbol: String,
        tint: Color = Palette.flow,
        help: String = "",
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.tint = tint
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .glyph(.caption)
                .foregroundStyle(tint)
                .frame(width: Control.compact, height: Control.compact)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Disabled treatment

extension View {
    /// One disabled appearance for the whole app: 0.4, same colour, same
    /// place. A control that vanishes when it cannot be used reads as a
    /// missing feature — which is how three pages ended up looking like they
    /// had no batch operations at all.
    public func actionEnabled(_ enabled: Bool) -> some View {
        disabled(!enabled)
            .opacity(enabled ? 1 : Motion.disabledOpacity)
            .animation(Motion.state, value: enabled)
    }
}
