import BrowserCore
import SwiftUI

struct ProfilesSettingsView: View {
    @Bindable var model: AppModel
    @Binding var selectedProfileID: UUID?
    let onAddProfile: () -> Void
    let onShowPrivacyInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ChocoSpace.u(18)) {
            Text(introduction).fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { _ in UnsupportedNotice.shared.show("プロファイルの詳細ヘルプ"); return .handled })
            HStack(alignment: .top, spacing: ChocoSpace.u(10)) {
                profileList
                VStack(alignment: .leading, spacing: ChocoSpace.u(27)) {
                    SettingsGroup {
                        SettingsRow("Search engine") {
                            SettingsDropdown(key: "settings.searchEngine", options: ["Google"], feature: "検索エンジンの変更")
                        }
                        SettingsRow("Manage search") { SettingsNoticeButton("Search Settings…", feature: "検索設定") }
                        SettingsFeatureToggle("Include search engine suggestions", key: "settings.searchSuggestions", defaultValue: true,
                                              feature: "検索候補", divider: false)
                    }
                    SettingsGroup {
                        SettingsRow("Archive tabs after", info: true) {
                            SettingsDropdown(key: "settings.archiveAfter", options: ["12 hours (default)", "24 hours", "7 days", "30 days"],
                                             feature: "タブの自動アーカイブ")
                        }
                        SettingsRow("New documents") {
                            SettingsDropdown(key: "settings.newDocuments", options: ["——"], feature: "新規ドキュメントの保存先")
                        }
                        SettingsRow("Download location", divider: false) {
                            SettingsDropdown(key: "settings.downloadLocation", options: ["Downloads"], feature: "ダウンロード先の変更", icon: "settings-9e9e6")
                        }
                    }
                    VStack(alignment: .leading, spacing: ChocoSpace.xs) {
                        Text("Your Data and Settings").font(ChocoTheme.font(11, weight: .semibold))
                            .foregroundStyle(SettingsStyle.secondary).padding(.leading, ChocoSpace.u(10))
                        SettingsGroup {
                            dataRow("Privacy and Security", icon: "428da", color: "0A84FF") { onShowPrivacyInfo() }
                            dataRow("Passwords", icon: "9a791", color: "30D158")
                            dataRow("Credit Cards", icon: "2ed07", color: "E6BE17")
                            dataRow("Notifications", icon: "796fe", color: "FF9F0A")
                            dataRow("Clear Browsing Data", icon: "2e000", color: "FF453A", divider: false)
                        }
                    }.padding(.top, ChocoSpace.u(11))
                }.frame(width: ChocoSpace.u(341))
            }
        }.padding(.horizontal, ChocoSpace.u(64)).padding(.top, ChocoSpace.u(20))
    }

    private var profileList: some View {
        VStack(spacing: 0) {
            Text("Your Profiles").font(ChocoTheme.font(11, weight: .semibold))
                .foregroundStyle(SettingsStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, ChocoSpace.u(15)).frame(height: ChocoSpace.u(26))
            Rectangle().fill(SettingsStyle.divider).frame(height: 1)
            ScrollView {
                VStack(spacing: ChocoSpace.xs) {
                    ForEach(model.state.profiles) { profile in
                        Button { selectedProfileID = profile.id } label: {
                            HStack(spacing: ChocoSpace.xs) {
                                Text(profile.name).lineLimit(1)
                                Spacer(minLength: 0)
                                let count = model.state.spaces.filter { $0.profileID == profile.id }.count
                                Text("\(count) \(count == 1 ? "Space" : "Spaces")").font(ChocoTheme.font(11))
                            }
                            .padding(.horizontal, ChocoSpace.u(6)).frame(height: ChocoSpace.u(32))
                            .background(selectedProfileID == profile.id ? Color(hex: "34303A") : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("settings-profile-\(profile.id)")
                            .accessibilityAddTraits(selectedProfileID == profile.id ? .isSelected : [])
                    }
                }.padding(.horizontal, ChocoSpace.u(15)).padding(.top, ChocoSpace.u(14))
            }
            HStack(spacing: 0) {
                Button { onAddProfile() } label: { DesignIcon("settings-c8b4e", size: 16).frame(width: ChocoSpace.u(32), height: ChocoSpace.u(28)) }
                    .accessibilityLabel("プロファイルを追加…").accessibilityIdentifier("settings-add-profile")
                Rectangle().fill(SettingsStyle.divider).frame(width: 1, height: ChocoSpace.u(16))
                Button { UnsupportedNotice.shared.show("プロファイルの削除") } label: { DesignIcon("settings-755b6", size: 16).frame(width: ChocoSpace.u(32), height: ChocoSpace.u(28)) }
                    .accessibilityLabel("プロファイルを削除")
                Rectangle().fill(SettingsStyle.divider).frame(width: 1, height: ChocoSpace.u(16))
                Button { UnsupportedNotice.shared.show("プロファイルの編集") } label: { DesignIcon("settings-b19b4", size: 18).frame(width: ChocoSpace.u(32), height: ChocoSpace.u(28)) }
                    .accessibilityLabel("プロファイルを編集")
                Spacer(minLength: 0)
            }.buttonStyle(.plain).frame(height: ChocoSpace.u(30))
                .overlay(alignment: .top) { Rectangle().fill(SettingsStyle.divider).frame(height: 1) }
        }
        .frame(width: ChocoSpace.u(205), height: ChocoSpace.u(478))
        .background(Color(hex: "1C1E20"), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
    }

    private func dataRow(_ title: String, icon: String, color: String, divider: Bool = true, action: (() -> Void)? = nil) -> some View {
        Button { if let action { action() } else { UnsupportedNotice.shared.show(title) } } label: {
            SettingsRow(title, icon: icon, iconColor: color, divider: divider) {
                DesignIcon("settings-5e94d", size: 16)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    /// Figma copy, with the blue "Learn more." link.
    private var introduction: AttributedString {
        var text = AttributedString("Profiles help keep your data separate across Spaces — like history, logins, cookies, and\nextensions. You can use any Profile across one or more Spaces. ")
        var link = AttributedString("Learn more.")
        link.link = URL(string: "choco-browser://profiles-help")
        link.foregroundColor = Color(hex: "3A84D4")
        text.append(link)
        return text
    }
}
