import SwiftUI

struct GeneralSettingsView: View {
    let onShowProfiles: () -> Void
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(MotionPreference.storageKey) private var motionPreference = MotionPreference.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsGroup {
                SettingsUnavailableToggle("Automatically update choco", info: true)
                SettingsUnavailableToggle("Warn before quitting", divider: false)
            }
            SettingsGroup {
                SettingsRow("Previews") { SettingsUnavailableButton("Previews Settings…") }
                SettingsRow("Manage your search engine and browsing data\nin Profile Settings.", divider: false) {
                    Button("Profile Settings…") { onShowProfiles() }.buttonStyle(SettingsButtonStyle())
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SettingsRow("外観") {
                    Picker("外観", selection: $appearance) {
                        Text("システムに合わせる").tag("system")
                        Text("ライト").tag("light")
                        Text("ダーク").tag("dark")
                    }.labelsHidden().frame(width: 180).accessibilityIdentifier("settings-appearance")
                }
                SettingsRow("アニメーション", divider: false) {
                    Picker("動き", selection: $motionPreference) {
                        ForEach(MotionPreference.allCases) { preference in Text(preference.label).tag(preference.rawValue) }
                    }.labelsHidden().frame(width: 180).accessibilityIdentifier("settings-motion")
                }
            }
            .padding(.horizontal, 10)
            .background(SettingsStyle.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
            .padding(.top, ChocoSpace.xl)
            Text("無効の項目はこのバージョンでは未対応です。")
                .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary).padding(.top, ChocoSpace.sm)
        }.padding(.horizontal, 64).padding(.top, 20)
    }
}
