import SwiftUI

struct AppsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .apps) {
            GlassCard {
                Text(t("应用列表即将在这里呈现。", "The app inventory lands here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
