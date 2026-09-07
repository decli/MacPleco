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
            // The sidebar's half of the masthead band: the mark and the
            // wordmark sit on the same baseline as the page title in the
            // column to the right, and on the same left edge (24) as the
            // destinations below.
            // 16, not 24: the floating sidebar is already inset 8 by the
            // system, and the destination rows below start at x=24. Measured,
            // 24 of padding here put the mark at 32 — one of the two edges
            // the whole masthead exercise exists to line up.
            BrandMasthead("MacPleco")
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.sm)

            List(selection: selection) {
                ForEach(Destination.allCases) { destination in
                    Label(destination.title, systemImage: destination.symbol)
                        .font(Typo.sidebarItem)
                        .tag(destination)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            Spacer(minLength: 0)
            capacityFooter
        }
    }

    private var capacityFooter: some View {
        let storage = model.storage
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("可用空间", "Free space"))
                    .font(Typo.captionStrong)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                Reading(bytes: storage.available, emphasis: .heading)
            }
            CapacityBar(
                fraction: storage.usedFraction,
                tint: storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua,
                weight: .thick
            )
            HStack {
                Text(t("共 \(Bytes.format(storage.total))", "\(Bytes.format(storage.total)) total"))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .glyph(.caption)
                            .foregroundStyle(Palette.inkTertiary)
                            .frame(width: Control.compact, height: Control.compact)
                            .contentShape(Rectangle())
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
        .animation(Motion.reveal, value: model.destination)
    }
}

// MARK: - Page scaffold

/// Standard page chrome.
///
/// Every page is: masthead band, subtitle, optional note, optional tabs, then
/// blocks — in that order, at that inset, at those sizes, on all six pages.
///
/// The masthead's trailing slot holds **exactly one** `standard` control and
/// never navigation. Tabs used to live there, which is why the slot had to
/// accommodate both a 24pt segmented control and a 32pt button, and why the
/// note under it was 14pt tall on one page and 32pt on another. Tabs switch
/// the list below them, so they belong above that list, on the content's own
/// left edge.
///
/// `navigationTitle` stays, because it names the window in Mission Control,
/// the Window menu and the accessibility tree. `.toolbar(removing: .title)`
/// stops it being *drawn* a second time in the title bar.
struct Page<Content: View>: View {
    let destination: Destination
    /// Overrides the destination's own line when a page has modes that do
    /// genuinely different things. The title never changes: that is the
    /// sidebar's word for where you are.
    var subtitle: String? = nil
    /// The one page-scoped control. Not navigation.
    var trailing: AnyView? = nil
    var note: AnyView? = nil
    /// Navigation between two views of this page, drawn above the content.
    var tabs: AnyView? = nil
    var maxContentWidth: CGFloat = Layout.contentWidth
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                // Masthead, subtitle, note and tabs are one group with fixed
                // internal spacing, so the first block starts at the same y on
                // every page whether or not the optional parts are present.
                VStack(alignment: .leading, spacing: 0) {
                    Masthead(title: destination.title) { trailing }

                    Text(subtitle ?? destination.subtitle)
                        .font(Typo.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .padding(.top, Space.sm)

                    if let note {
                        note.padding(.top, Space.sm)
                    }

                    if let tabs {
                        tabs.padding(.top, Space.lg)
                    }
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
    /// The window-level naming every page shares.
    func pageChrome(_ destination: Destination) -> some View {
        navigationTitle(destination.title)
            .toolbar(removing: .title)
    }
}
