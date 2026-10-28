import SwiftUI

struct AdvancedSettingsView: View {
    let onShowGeneral: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup {
                SettingsFeatureToggle("Play choco-browser sound effects", key: "settings.soundEffects", defaultValue: true,
                                      feature: "効果音", icon: "7d0b0", color: "0A84FF")
                SettingsFeatureToggle("Haptic feedback when reordering tabs", key: "settings.haptics", defaultValue: true,
                                      feature: "触覚フィードバック", icon: "87172", color: "0A84FF", divider: false)
            }
            SettingsGroup {
                // Restoring the previous session is how the app always starts, so the switch reports that.
                SettingsFeatureToggle("When opening choco-browser, restore windows from previous session", key: "settings.restoreSession",
                                      defaultValue: true, feature: "セッション復元の切り替え", icon: "08a1b", color: "30D158", fixed: true)
                SettingsFeatureToggle("Allow window dragging from the top of webpages", key: "settings.dragFromWebpage", defaultValue: true,
                                      feature: "ページ上部からのウィンドウ移動", icon: "12d45", color: "30D158")
                SettingsFeatureToggle("Show full URL when Toolbar is enabled", key: "settings.fullURL", defaultValue: false,
                                      feature: "完全なURLの表示", icon: "87a9e", color: "FF453A")
                SettingsFeatureToggle("Enable Shared Quotes when highlighting text.", key: "settings.sharedQuotes", defaultValue: true,
                                      feature: "共有引用", subtitle: "If disabled, you can still copy URL as a quote using ^⇧⌘C.",
                                      icon: "13bf5", color: "FF453A", divider: false)
            }.padding(.top, ChocoSpace.u(18))
            SettingsGroup {
                SettingsFeatureToggle("Enable Picture in Picture when you leave a video tab", key: "settings.pictureInPicture", defaultValue: true,
                                      feature: "ピクチャインピクチャ", icon: "9190b", color: "D63AF0")
                SettingsFeatureToggle("Allow websites to get your theme data", key: "settings.themeData", defaultValue: true,
                                      feature: "テーマデータの共有", icon: "12da1", color: "D63AF0")
                SettingsFeatureToggle("Enable Boosts on websites you visit", key: "settings.boosts", defaultValue: true,
                                      feature: "Boost", icon: "54dc6", color: "D63AF0", divider: false)
            }.padding(.top, ChocoSpace.u(40))
            HStack(spacing: ChocoSpace.u(5)) {
                Button("More Settings…") { onShowGeneral() }.buttonStyle(SettingsButtonStyle())
                SettingsNoticeButton("Reset Translated-site Prompts", feature: "翻訳プロンプトのリセット")
                Spacer(minLength: 0)
                SettingsNoticeButton("Export Data", feature: "データのエクスポート")
            }.padding(.top, ChocoSpace.xl)
        }.padding(.horizontal, ChocoSpace.u(64)).padding(.top, ChocoSpace.u(20))
    }
}
