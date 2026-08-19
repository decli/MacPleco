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

/// A real selectable sidebar `List` lets macOS own selection, hover, focus and
/// keyboard interaction. On macOS 26 that also means the system, rather than a
/// hand-drawn gradient, supplies the native Liquid Glass selection treatment.
struct SidebarColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            List(selection: selection) {
                ForEach(Destination.allCases) { destination in
                    Label(destination.title, systemImage: destination.symbol)
                        .font(.system(size: 14.5, weight: .medium))
                        .tag(destination)
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
                    .contentTransition(.numericText())
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

    private var selection: Binding<Destination?> {
        Binding(
            get: { model.destination },
            set: { destination in
                guard let destination, destination != model.destination else { return }
                model.destination = destination
            }
        )
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
        // Sections cross-fade rather than cutting. A plain fade, not a slide:
        // each page already assembles itself with a staggered rise, and two
        // motions layered on one another reads as busy instead of smooth.
        .id(model.destination)
        .transition(.opacity)
        .animation(.smooth(duration: 0.28), value: model.destination)
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
