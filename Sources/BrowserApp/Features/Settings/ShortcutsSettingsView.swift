import SwiftUI

struct ShortcutsSettingsView: View {
    @Binding var shortcutQuery: String
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: ChocoSpace.xxl) {
            HStack(spacing: 10) {
                Text("Start with the basics")
                Button { shortcutQuery = ""; searchFocused = true } label: {
                    HStack(spacing: 6) {
                        Text("⌘").font(ChocoTheme.font(9)).foregroundStyle(SettingsStyle.accent)
                            .frame(width: 14, height: 14).background(.white.opacity(0.9), in: Circle())
                        Text("Learn the Essential Shortcuts").font(ChocoTheme.font(13, weight: .medium))
                    }.padding(.leading, 6).padding(.trailing, 10).frame(height: 24)
                        .background(SettingsStyle.accent, in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain)
            }.padding(.leading, ChocoSpace.lg).padding(.trailing, ChocoSpace.xs).padding(.vertical, ChocoSpace.xs)
                .background(Color(hex: "4B484E"), in: RoundedRectangle(cornerRadius: 6))
            HStack(alignment: .top, spacing: ChocoSpace.lg) {
                VStack(spacing: 0) {
                    HStack(spacing: ChocoSpace.sm) {
                        DesignIcon("settings-9e512", size: 16)
                        TextField("Type a feature name or shortcut", text: $shortcutQuery)
                            .textFieldStyle(.plain).focused($searchFocused).accessibilityIdentifier("settings-shortcut-search")
                    }.padding(.horizontal, 14).frame(height: 36).background(SettingsStyle.field)
                    Text("Default Shortcuts").font(ChocoTheme.font(11, weight: .semibold)).foregroundStyle(SettingsStyle.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, ChocoSpace.lg).frame(height: 32).background(SettingsStyle.card)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredShortcuts) { shortcut in
                                HStack {
                                    Text(shortcut.title)
                                    Spacer(minLength: 4)
                                    Text(shortcut.keys).font(ChocoTheme.font(12, weight: .medium))
                                        .foregroundStyle(Color(hex: "1E1E1F"))
                                        .frame(width: 62, height: 22).background(.white, in: RoundedRectangle(cornerRadius: 5))
                                }.frame(height: 36)
                                    .overlay(alignment: .bottom) { Rectangle().fill(SettingsStyle.divider).frame(height: 1) }
                            }
                            if filteredShortcuts.isEmpty {
                                Text("一致するショートカットがありません").foregroundStyle(SettingsStyle.secondary).padding(.vertical, ChocoSpace.xl)
                            }
                        }.padding(.horizontal, ChocoSpace.xl).padding(.top, ChocoSpace.md)
                    }
                }.frame(width: 340, height: 460).background(SettingsStyle.button)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
                VStack(alignment: .leading, spacing: 0) {
                    // Figma draws the 4pt key outlines 70pt wide, overlapping by 2pt and hanging 4pt left of the text column.
                    HStack(spacing: -2) {
                        keyIllustration { Text("⌘").font(ChocoTheme.font(30, weight: .bold)).foregroundStyle(SettingsStyle.accent) }
                        keyIllustration { DesignIcon("settings-e2a54", size: 62) }
                    }.padding(.top, -2).padding(.leading, -4)
                    Text("Custom Shortcuts").font(ChocoTheme.font(13, weight: .semibold)).padding(.top, 23)
                    Text("ショートカットの変更は未対応です。\n左の一覧から、現在使える操作を\n検索できます。")
                        .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary).padding(.top, 10)
                    Spacer()
                    HStack(spacing: 2) {
                        SettingsUnavailableButton("Reset All Shortcuts")
                        Button {} label: { DesignIcon("settings-01a0f", size: 16).frame(width: 24, height: 24) }
                            .buttonStyle(.plain).background(SettingsStyle.button, in: Circle()).disabled(true)
                            .accessibilityLabel("ショートカットのその他の操作（未対応）")
                    }.padding(.bottom, 9)
                }.frame(width: 200, height: 460, alignment: .topLeading)
            }
        }.padding(.horizontal, 64).padding(.top, 20)
    }

    private var filteredShortcuts: [SettingsShortcut] { SettingsShortcut.matching(shortcutQuery) }

    private func keyIllustration<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(width: 70, height: 70)
            .background(Color(hex: "E5D4E5"), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "8F4791"), lineWidth: 4) }
            .accessibilityHidden(true)
    }
}
