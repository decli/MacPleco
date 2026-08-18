import SwiftUI
import AppKit

public struct RootView: View {
    @Environment(AppModel.self) private var model

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            DetailHost()
        }
        .background {
            AmbientBackground(energetic: model.clean.isScanning || model.clean.isCleaning)
        }
        .tint(Palette.aqua)
        .frame(minWidth: 980, minHeight: 660)
        .task { model.bootstrap() }
        // Switching language rebuilds the tree; `t()` is resolved at view
        // construction, so a plain state change would not repaint.
        .id(model.language)
        .preferredColorScheme(model.appearance.scheme)
    }
}

// MARK: - Sidebar

/// Hand-built navigation instead of `List(selection:)`.
///
/// The system list paints its selection with the user's accent colour — a blue
/// pill in a teal app, as the first build demonstrated — and its typography
/// runs small. Building the rows by hand buys the brand-coloured sliding pill,
/// larger type, hover states, and ⌘1–6 shortcuts.
struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Namespace private var pill

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            VStack(spacing: Space.xs) {
                ForEach(Array(Destination.allCases.enumerated()), id: \.element) { index, destination in
                    navRow(destination, shortcut: index + 1)
                }
            }
            .padding(.horizontal, Space.md)
            Spacer(minLength: 0)
            capacityFooter
        }
        .frame(width: 248)
        .frame(maxHeight: .infinity)
        .glassSurface(Rectangle())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 0.5)
        }
        .bleedUnderChrome()
    }

    // The traffic lights float over this area (transparent title bar), so the
    // wordmark starts below them.
    private var brand: some View {
        HStack(spacing: Space.sm + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.aquaSweep)
                    .frame(width: 30, height: 30)
                    .shadow(color: Palette.aqua.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "fish.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("MacPleco")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
        .padding(.top, 52)
        .padding(.horizontal, Space.lg + Space.xs)
        .padding(.bottom, Space.xl)
    }

    private func navRow(_ destination: Destination, shortcut: Int) -> some View {
        SidebarRow(
            destination: destination,
            selected: model.destination == destination,
            namespace: pill,
            shortcut: shortcut
        ) {
            guard model.destination != destination else { return }
            withAnimation(.snappy(duration: 0.32, extraBounce: 0.08)) {
                model.destination = destination
            }
        }
    }

    private var capacityFooter: some View {
        let storage = model.storage
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("可用空间", "Free space"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                Text(Bytes.format(storage.available))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            CapacityBar(
                fraction: storage.usedFraction,
                tint: storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua,
                height: 5
            )
            HStack {
                Text(t("共 \(Bytes.format(storage.total))", "\(Bytes.format(storage.total)) total"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(t("设置", "Settings"))
                }
            }
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.row)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.md)
    }
}

/// One sidebar destination. A standalone view (not a ButtonStyle) because
/// hover state inside a style struct is reconstructed every render and never
/// actually updates.
private struct SidebarRow: View {
    let destination: Destination
    let selected: Bool
    let namespace: Namespace.ID
    let shortcut: Int
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 15, weight: selected ? .semibold : .medium))
                    .frame(width: 22)
                Text(destination.title)
                    .font(.system(size: 14.5, weight: selected ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color.white : Palette.inkSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 10)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(Palette.aquaSweep)
                        .shadow(color: Palette.aqua.opacity(0.35), radius: 8, y: 3)
                        .matchedGeometryEffect(id: "nav-pill", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(Palette.wellFill)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.smooth(duration: 0.16)) { hovering = inside }
        }
        .keyboardShortcut(KeyEquivalent(Character("\(shortcut)")), modifiers: .command)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Detail host

struct DetailHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.destination {
            case .overview: OverviewView()
            case .clean: CleanView()
            case .apps: AppsView()
            case .space: SpaceView()
            case .tune: TuneView()
            case .monitor: MonitorView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page scaffold

/// Standard page chrome: a header pinned above a scrolling body.
///
/// Content is constrained to a readable column and centred, so a huge window
/// gains atmosphere at the edges instead of a smear of left-aligned cards and
/// a sea of blank space to their right.
struct Page<Content: View>: View {
    let destination: Destination
    var trailing: AnyView? = nil
    var maxContentWidth: CGFloat = 1140
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            PageHeader(title: destination.title, subtitle: destination.subtitle) {
                if let trailing { trailing }
            }
            .padding(.horizontal, Space.xxl + Space.sm)
            .padding(.top, Space.xxl + Space.md)
            .frame(maxWidth: maxContentWidth + 2 * (Space.xxl + Space.sm))
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    content()
                }
                .padding(.horizontal, Space.xxl + Space.sm)
                .padding(.bottom, Space.xxl + Space.md)
                .frame(maxWidth: maxContentWidth + 2 * (Space.xxl + Space.sm))
                .frame(maxWidth: .infinity)
            }
            .softScrollEdges()
        }
        // Re-run entrance staggering when the section changes.
        .id(destination)
    }
}
