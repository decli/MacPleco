import SwiftUI
import AppKit

/// The shell is deliberately the SYSTEM shell.
///
/// v0.2 hand-built the sidebar and hid the title bar to control every pixel —
/// and immediately stopped looking like a Mac app, because on macOS 26 the
/// unmistakable Liquid Glass chrome (the floating sidebar, the toolbar pills)
/// belongs to the system containers. `NavigationSplitView` plus real
/// `.toolbar` items get that glass drawn by the OS itself; our own
/// `glassEffect` work is reserved for content cards, where custom elements
/// are legitimate.
public struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var columns = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SidebarColumn()
                .navigationSplitViewColumnWidth(min: 224, ideal: 244, max: 300)
        } detail: {
            DetailHost()
                .background {
                    AmbientBackground()
                        // The API's actual purpose: let the detail's backdrop
                        // continue under the glass sidebar and toolbar.
                        .bleedUnderChrome()
                }
        }
        .navigationSplitViewStyle(.balanced)
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

/// Rows live inside a real sidebar `List`, so the column keeps the system's
/// Liquid Glass material. Selection is our own quiet aqua capsule — rendered
/// per row, not by the List, so the user's system accent colour never fights
/// the brand.
struct SidebarColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            List {
                ForEach(Array(Destination.allCases.enumerated()), id: \.element) { index, destination in
                    SidebarRow(
                        destination: destination,
                        selected: model.destination == destination,
                        shortcut: index + 1
                    ) {
                        guard model.destination != destination else { return }
                        withAnimation(.snappy(duration: 0.28)) {
                            model.destination = destination
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            Spacer(minLength: 0)
            capacityFooter
        }
    }

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
        .padding(.top, Space.md)
        .padding(.horizontal, Space.lg + Space.xs)
        .padding(.bottom, Space.sm)
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
        .background {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .fill(Palette.wellFill)
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.md)
    }
}

private struct SidebarRow: View {
    let destination: Destination
    let selected: Bool
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
            .padding(.vertical, 9)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(Palette.aquaSweep)
                        .shadow(color: Palette.aqua.opacity(0.35), radius: 7, y: 2)
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

/// Standard page chrome. The title and subtitle go through the REAL navigation
/// bar (`navigationTitle`/`navigationSubtitle`), and page actions become real
/// `.toolbar` items — on macOS 26 both render in the system's Liquid Glass,
/// which no hand-rolled header can imitate.
struct Page<Content: View>: View {
    let destination: Destination
    var trailing: AnyView? = nil
    var maxContentWidth: CGFloat = 1140
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                content()
            }
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: maxContentWidth + 2 * Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .navigationTitle(destination.title)
        .navigationSubtitle(destination.subtitle)
        .toolbar {
            if let trailing {
                ToolbarItem(placement: .primaryAction) { trailing }
            }
        }
        // Re-run entrance staggering when the section changes.
        .id(destination)
    }
}
