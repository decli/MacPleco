import SwiftUI

struct SpaceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .space) {
            GlassCard {
                Text(t("空间地图即将在这里呈现。", "The space map lands here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
