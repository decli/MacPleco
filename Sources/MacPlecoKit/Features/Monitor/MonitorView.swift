import SwiftUI

struct MonitorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(destination: .monitor) {
            GlassCard {
                Text(t("实时监控即将在这里呈现。", "Live monitoring lands here."))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
