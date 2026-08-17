import SwiftUI

public struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        @Bindable var model = model

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 212, ideal: 228, max: 300)
        } detail: {
            DetailHost()
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            Palette.tankGradient
                .ignoresSafeArea()
        }
        .tint(Palette.aqua)
        .frame(minWidth: 960, minHeight: 640)
        .task { model.bootstrap() }
        // Switching language rebuilds the tree; `t()` is resolved at view
        // construction, so a plain state change would not repaint.
        .id(model.language)
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            brand
            List(Destination.allCases, selection: $model.destination) { destination in
                Label {
                    Text(destination.title)
                        .font(.system(size: 13, weight: .medium))
                } icon: {
                    Image(systemName: destination.symbol)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 1)
                .tag(destination)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            Spacer(minLength: 0)
            capacityFooter
        }
        .bleedUnderChrome()
    }

    // The traffic lights float over this area because the title bar is hidden,
    // so the wordmark starts below them rather than beside them.
    private var brand: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "fish.fill")
                .font(.system(size: 15))
                .foregroundStyle(Palette.aquaSweep)
            Text("MacPleco")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
        .padding(.top, Space.huge)
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    private var capacityFooter: some View {
        let storage = model.storage
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("可用空间", "Free space"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                Spacer()
                Text(Bytes.format(storage.available))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            CapacityBar(
                fraction: storage.usedFraction,
                tint: storage.usedFraction > 0.9 ? Palette.caution : Palette.aqua,
                height: 5
            )
            Text(
                t(
                    "共 \(Bytes.format(storage.total))",
                    "\(Bytes.format(storage.total)) total"
                )
            )
            .font(.system(size: 10))
            .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Space.md)
        .glassPanel(radius: Radius.row)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.md)
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
        .background {
            Palette.tankGradient.ignoresSafeArea()
        }
    }
}

// MARK: - Page scaffold

/// Standard page chrome: a header pinned above a scrolling body, with the
/// generous top inset the hidden title bar requires.
struct Page<Content: View>: View {
    let destination: Destination
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            PageHeader(title: destination.title, subtitle: destination.subtitle) {
                if let trailing { trailing }
            }
            .padding(.horizontal, Space.xxl)
            .padding(.top, Space.xxl)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    content()
                }
                .padding(.horizontal, Space.xxl)
                .padding(.bottom, Space.xxl)
            }
            .softScrollEdges()
        }
    }
}
