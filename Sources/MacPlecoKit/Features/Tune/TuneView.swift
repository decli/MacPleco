import SwiftUI

struct TuneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .tune) {
            GlassCard {
                Text(t("优化任务即将在这里呈现。", "Tune-up tasks land here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
