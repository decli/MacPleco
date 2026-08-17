import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .overview) {
            GlassCard {
                Text(t("概览即将在这里呈现。", "The overview lands here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
