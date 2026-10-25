import BrowserCore
import SwiftUI

struct ProfilesSettingsView: View {
    @Bindable var model: AppModel
    @Binding var selectedProfileID: UUID?
    let onAddProfile: () -> Void
    let onShowPrivacyInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("Profiles keep logins and cookies separate across Spaces.\nYou can use a Profile across one or more Spaces.")
                .lineSpacing(1).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                profileList
                VStack(alignment: .leading, spacing: 27) {
                    SettingsGroup {
                        SettingsRow("Search engine") { SettingsFixedValue("DuckDuckGo") }
                        SettingsRow("Manage search") { SettingsUnavailableButton("Search Settings…") }
                        SettingsUnavailableToggle("Search engine suggestions", divider: false)
                    }
                    SettingsGroup {
                        SettingsRow("Archive tabs after", info: true) { SettingsFixedValue("Manually") }
                        SettingsRow("New documents") { SettingsFixedValue("—") }
                        SettingsRow("Download location", divider: false) {
                            HStack(spacing: 6) {
                                DesignIcon("settings-9e9e6", size: 16)
                                Text("Downloads")
                                DesignIcon("settings-4e45f", size: 12)
                            }.frame(width: 144, height: 24).background(SettingsStyle.button, in: RoundedRectangle(cornerRadius: 6))
                        }.disabled(true).help("ダウンロード管理は未対応です。")
                    }
                    VStack(alignment: .leading, spacing: ChocoSpace.xs) {
                        Text("Your Data and Settings").font(ChocoTheme.font(11, weight: .medium))
                            .foregroundStyle(SettingsStyle.secondary).padding(.leading, 10)
                        SettingsGroup {
                            dataRow("Privacy and Security", icon: "428da", color: "0A84FF", available: true)
                            dataRow("Passwords", icon: "9a791", color: "30D158")
                            dataRow("Credit Cards", icon: "2ed07", color: "E6BE17")
                            dataRow("Notifications", icon: "796fe", color: "FF9F0A")
                            dataRow("Clear Browsing Data", icon: "2e000", color: "FF453A", divider: false)
                        }
                    }.padding(.top, 11)
                }.frame(width: 341)
            }
        }.padding(.horizontal, 64).padding(.top, 20)
    }

    private var profileList: some View {
        VStack(spacing: 0) {
            Text("Your Profiles").font(ChocoTheme.font(11, weight: .semibold))
                .foregroundStyle(SettingsStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, ChocoSpace.lg).frame(height: 28)
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
                            .padding(.horizontal, 6).frame(height: 32)
                            .background(selectedProfileID == profile.id ? Color(hex: "35313C") : .clear, in: RoundedRectangle(cornerRadius: 5))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("settings-profile-\(profile.id)")
                            .accessibilityAddTraits(selectedProfileID == profile.id ? .isSelected : [])
                    }
                }.padding(.horizontal, 16).padding(.top, 14)
            }
            HStack(spacing: 0) {
                Button { onAddProfile() } label: { DesignIcon("settings-c8b4e", size: 16).frame(width: 32, height: 28) }
                    .accessibilityLabel("プロファイルを追加…").accessibilityIdentifier("settings-add-profile")
                Rectangle().fill(SettingsStyle.divider).frame(width: 1, height: 16)
                Button {} label: { DesignIcon("settings-755b6", size: 16).frame(width: 32, height: 28) }
                    .disabled(true).accessibilityLabel("プロファイルを削除（未対応）")
                Rectangle().fill(SettingsStyle.divider).frame(width: 1, height: 16)
                Button {} label: { DesignIcon("settings-b19b4", size: 18).frame(width: 32, height: 28) }
                    .disabled(true).accessibilityLabel("プロファイルのその他の操作（未対応）")
                Spacer(minLength: 0)
            }.buttonStyle(.plain).frame(height: 30)
                .overlay(alignment: .top) { Rectangle().fill(SettingsStyle.divider).frame(height: 1) }
        }
        .frame(width: 205, height: 478)
        .background(Color(hex: "1D1F21"), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
    }

    private func dataRow(_ title: String, icon: String, color: String, available: Bool = false, divider: Bool = true) -> some View {
        Button { onShowPrivacyInfo() } label: {
            SettingsRow(title, icon: icon, iconColor: color, divider: divider) {
                DesignIcon("settings-5e94d", size: 16)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!available)
            .help(available ? "このブラウザのデータの扱いを表示" : "このバージョンでは未対応です。")
    }
}
