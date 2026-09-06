import SwiftUI
import AppKit

/// The shell is deliberately the SYSTEM shell.
///
/// v0.2 hand-built the sidebar and hid the title bar to control every pixel —
/// and immediately stopped looking like a Mac app, because on macOS 26 the
/// unmistakable Liquid Glass chrome (the floating sidebar, the window's own
/// title bar) belongs to the system containers. `NavigationSplitView` gets
/// that glass drawn by the OS itself; our own `glassEffect` work is reserved
/// for content cards, where custom elements are legitimate.
///
/// Page *controls* used to be `.toolbar` items for the same reason, and that
/// was the one place the argument did not hold: a page's own control is not
/// window chrome, and putting it there pinned it to the right edge of the
/// window instead of the right edge of the content, on the three pages that
/// happened to have one. They live in `PageHeader` now.
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
                        .font(.system(size: Typo.Step.subhead, weight: .medium))
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
                    .font(.system(size: Typo.Step.subhead, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("MacPleco")
                .font(.system(size: Typo.Step.cardTitle, weight: .bold, design: .rounded))
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
                    .font(Typo.captionStrong)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                Text(Bytes.format(storage.available))
                    .font(.system(size: Typo.Step.body, weight: .semibold, design: .rounded))
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
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: Typo.Step.caption))
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

/// Standard page chrome.
///
/// Every page is: header, then optional note, then blocks — in that order, at
/// that inset, at those sizes, on all six pages. The header's `trailing` slot
/// is the one place a page-scoped control goes; see `PageHeader` for why it
/// moved out of the toolbar.
///
/// `navigationTitle` stays, because it names the window in Mission Control,
/// the Window menu and the accessibility tree. `.toolbar(removing: .title)`
/// stops it being *drawn* a second time in the title bar, where it would
/// duplicate the header two lines below it.
struct Page<Content: View>: View {
    let destination: Destination
    /// Overrides the destination's own line when a page has modes that do
    /// genuinely different things — Apps' two tabs, say. The title never
    /// changes: that is the sidebar's word for where you are.
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    var note: AnyView? = nil
    var maxContentWidth: CGFloat = 1140
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                // Header and note are one group: Space.sm between them, so
                // the note reads as part of the heading rather than as the
                // first block. Blocks below sit Space.lg apart, so the group
                // clears them by Space.lg + Space.sm — comfortably more than
                // the gap *within* any group, which is what makes it read as
                // a heading instead of as content.
                VStack(alignment: .leading, spacing: Space.sm) {
                    PageHeader(
                        title: destination.title,
                        subtitle: subtitle ?? destination.subtitle
                    ) {
                        trailing
                    }
                    if let note { note }
                }
                .rises(0)
                .padding(.bottom, Space.sm)

                // Applied to each block, not to the group: a modifier on
                // ViewBuilder content distributes over its elements, which is
                // why the padding above could not live here.
                content()
                    .environment(\.staggerBase, 1)
            }
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: maxContentWidth + 2 * Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .pageChrome(destination)
        // Re-run entrance staggering when the section changes.
        .id(destination)
    }
}

extension View {
    /// The window-level naming every page shares. Split out so `SpaceView`,
    /// which builds its own scroll views, cannot drift from it.
    func pageChrome(_ destination: Destination) -> some View {
        navigationTitle(destination.title)
            .toolbar(removing: .title)
    }
}
