import SwiftUI

struct GeneralSettingsView: View {
    let onShowProfiles: () -> Void
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(MotionPreference.storageKey) private var motionPreference = MotionPreference.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: ChocoSpace.u(9)) {
            SettingsGroup {
                SettingsFeatureToggle("Automatically update choco-browser", key: "settings.autoUpdate", defaultValue: false,
                                      feature: "自動アップデート", info: true)
                SettingsFeatureToggle("Warn before quitting", key: "settings.warnBeforeQuitting", defaultValue: true,
                                      feature: "終了前の確認", divider: false)
            }
            SettingsGroup {
                SettingsRow("Previews") { SettingsNoticeButton("Previews Settings…", feature: "プレビュー") }
                SettingsRow("Manage your default search engine, Auto-Archive, and\ndownloads in Profile Settings.", divider: false) {
                    Button("Profile Settings…") { onShowProfiles() }.buttonStyle(SettingsButtonStyle())
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SettingsRow("外観") {
                    Picker("外観", selection: $appearance) {
                        Text("システムに合わせる").tag("system")
                        Text("ライト").tag("light")
                        Text("ダーク").tag("dark")
                    }.labelsHidden().frame(width: ChocoSpace.u(180)).accessibilityIdentifier("settings-appearance")
                }
                SettingsRow("アニメーション", divider: false) {
                    Picker("動き", selection: $motionPreference) {
                        ForEach(MotionPreference.allCases) { preference in Text(preference.label).tag(preference.rawValue) }
                    }.labelsHidden().frame(width: ChocoSpace.u(180)).accessibilityIdentifier("settings-motion")
                }
            }
            .padding(.horizontal, ChocoSpace.u(10))
            .background(SettingsStyle.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
            .padding(.top, ChocoSpace.xl)
        }.padding(.horizontal, ChocoSpace.u(64)).padding(.top, ChocoSpace.u(20))
    }
}
