import SwiftUI

struct CleanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .clean) {
            GlassCard {
                Text(t("清理面板即将在这里呈现。", "The clean panel lands here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
