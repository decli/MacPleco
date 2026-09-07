import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Binding private var menuBarEnabled: Bool

    init(menuBarEnabled: Binding<Bool>) {
        _menuBarEnabled = menuBarEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionLabel(t("语言", "Language"))
                Picker("", selection: languageBinding) {
                    ForEach(Lang.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(Control.size(for: Control.standard))
                .frame(width: 240, height: Control.standard)
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                SectionLabel(t("外观", "Appearance"))
                Picker("", selection: appearanceBinding) {
                    ForEach(Appearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(Control.size(for: Control.standard))
                .frame(width: 300, height: Control.standard)
                Text(
                    t(
                        "液态玻璃在深色的水里最好看。",
                        "Liquid Glass looks its best in dark water."
                    )
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                SectionLabel(t("菜单栏", "Menu bar"))
                ChoiceToggle(
                    t("在菜单栏显示小鱼", "Show the fish in the menu bar"),
                    isOn: $menuBarEnabled
                )
                Text(
                    t(
                        "随时看到剩余空间，一步进入清理。",
                        "Free space at a glance, cleaning one click away."
                    )
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            }

            Divider().overlay(Palette.hairline)

            HStack(spacing: Space.md) {
                Image(systemName: model.permissions.hasFullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .glyph(.row)
                    .foregroundStyle(model.permissions.hasFullDiskAccess ? Palette.positive : Palette.caution)
                Text(
                    model.permissions.hasFullDiskAccess
                        ? t("已获得完全磁盘访问权限", "Full Disk Access granted")
                        : t("尚未获得完全磁盘访问权限", "Full Disk Access not granted")
                )
                .font(Typo.body)
                .foregroundStyle(Palette.ink)
                Spacer()
                Button(t("打开设置", "Open Settings")) {
                    model.permissions.openSettings()
                }
                .buttonStyle(ActionButtonStyle(.neutral, height: Control.emphasis))
            }

            if model.ledger.totalRuns > 0 {
                HStack(spacing: Space.md) {
                    Image(systemName: "fish.fill")
                        .glyph(.row)
                        .foregroundStyle(Palette.aqua)
                    Text(
                        t(
                            "累计已腾出 \(Bytes.format(model.ledger.totalBytes)) · \(model.ledger.totalRuns) 次清理",
                            "\(Bytes.format(model.ledger.totalBytes)) freed across \(model.ledger.totalRuns) cleans"
                        )
                    )
                    .font(Typo.body)
                    .foregroundStyle(Palette.ink)
                    Spacer()
                    Button(t("清零统计", "Reset stats")) {
                        model.ledger.reset()
                    }
                    .buttonStyle(TextButtonStyle(.quiet))
                }
            }

            Divider().overlay(Palette.hairline)

            about

            Spacer(minLength: 0)
        }
        .padding(Space.xxl)
        .frame(width: 480, height: 560)
        .background {
            AmbientBackground()
        }
        .id(model.language)
        .preferredColorScheme(model.appearance.scheme)
    }

    private var languageBinding: Binding<Lang> {
        Binding(
            get: { model.language },
            set: { model.switchLanguage(to: $0) }
        )
    }

    private var appearanceBinding: Binding<Appearance> {
        Binding(
            get: { model.appearance },
            set: { model.appearance = $0 }
        )
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.md) {
                IconTile("fish.fill", box: .medium, style: .brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacPleco \(appVersion)")
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                    Text(t("GPL-3.0 开源许可", "Licensed under GPL-3.0"))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
            }

            Text(
                t(
                    "灵感来自 tw93 的命令行工具 Mole。如果你习惯用终端，推荐直接用它。",
                    "Inspired by Mole, tw93's terminal-first toolkit. If you live in a terminal, use that instead."
                )
            )
            .font(Typo.caption)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.lg) {
                Link(t("项目主页", "Project page"), destination: URL(string: "https://github.com/decli/MacPleco")!)
                Link(t("反馈问题", "Report an issue"), destination: URL(string: "https://github.com/decli/MacPleco/issues")!)
                Link("Mole", destination: URL(string: "https://github.com/tw93/Mole")!)
            }
            .font(Typo.caption)
            .tint(Palette.flow)
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
