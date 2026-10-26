import SwiftUI

struct AdvancedSettingsView: View {
    let onShowGeneral: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup {
                SettingsUnavailableToggle("Play choco-browser sound effects", icon: "7d0b0", color: "0A84FF")
                SettingsUnavailableToggle("Haptic feedback when reordering tabs", icon: "87172", color: "0A84FF", divider: false)
            }
            SettingsGroup {
                SettingsUnavailableToggle("When opening choco-browser, restore the previous session", icon: "08a1b", color: "30D158", value: true,
                                  help: "起動時のタブ構成の復元は常に有効です。")
                SettingsUnavailableToggle("Allow window dragging from the top of webpages", icon: "12d45", color: "30D158")
                SettingsUnavailableToggle("Show full URL when Toolbar is enabled", icon: "87a9e", color: "FF453A")
                SettingsUnavailableToggle("Enable Shared Quotes when highlighting text", icon: "13bf5", color: "FF453A", divider: false)
            }.padding(.top, 18)
            SettingsGroup {
                SettingsUnavailableToggle("Enable Picture in Picture when you leave a video tab", icon: "9190b", color: "D63AF0")
                SettingsUnavailableToggle("Allow websites to get your theme data", icon: "12da1", color: "D63AF0")
                SettingsUnavailableToggle("Enable Boosts on websites you visit", icon: "54dc6", color: "D63AF0", divider: false)
            }.padding(.top, 40)
            HStack(spacing: 5) {
                Button("More Settings…") { onShowGeneral() }.buttonStyle(SettingsButtonStyle())
                SettingsUnavailableButton("Reset Translated-site Prompts")
                Spacer(minLength: 0)
                SettingsUnavailableButton("Export Data")
            }.padding(.top, ChocoSpace.xl)
            Text("無効の項目はこのバージョンでは変更できません。")
                .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary).padding(.top, 18)
            Text("choco-browser · macOS 15.4+ · SwiftUI + WebKit · MIT")
                .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary).padding(.top, ChocoSpace.sm)
        }.padding(.horizontal, 64).padding(.top, 20)
    }
}
