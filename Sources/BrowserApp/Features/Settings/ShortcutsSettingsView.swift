import SwiftUI

struct ShortcutsSettingsView: View {
    @Binding var shortcutQuery: String
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: ChocoSpace.xxl) {
            HStack(spacing: ChocoSpace.u(10)) {
                Text("Start with the basics")
                Button { shortcutQuery = ""; searchFocused = true } label: {
                    HStack(spacing: ChocoSpace.u(6)) {
                        Text("⌘").font(ChocoTheme.font(9)).foregroundStyle(SettingsStyle.accent)
                            .frame(width: ChocoSpace.u(14), height: ChocoSpace.u(14)).background(.white.opacity(0.9), in: Circle())
                        Text("Learn the Essential Shortcuts").font(ChocoTheme.font(13, weight: .medium))
                    }.padding(.leading, ChocoSpace.u(6)).padding(.trailing, ChocoSpace.u(10)).frame(height: ChocoSpace.u(24))
                        .background(SettingsStyle.accent, in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain)
            }.padding(.leading, ChocoSpace.lg).padding(.trailing, ChocoSpace.xs).padding(.vertical, ChocoSpace.xs)
                .background(Color(hex: "4B484E"), in: RoundedRectangle(cornerRadius: 6))
            HStack(alignment: .top, spacing: ChocoSpace.lg) {
                VStack(spacing: 0) {
                    HStack(spacing: ChocoSpace.sm) {
                        DesignIcon("settings-9e512", size: 16)
                        TextField("Type a feature name or shortcut (like “Command+T”)", text: $shortcutQuery)
                            .textFieldStyle(.plain).focused($searchFocused).accessibilityIdentifier("settings-shortcut-search")
                    }.padding(.horizontal, ChocoSpace.u(14)).frame(height: ChocoSpace.u(36)).background(SettingsStyle.field)
                    Text("Default Shortcuts").font(ChocoTheme.font(11, weight: .semibold)).foregroundStyle(SettingsStyle.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, ChocoSpace.lg).frame(height: ChocoSpace.u(32)).background(SettingsStyle.card)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredShortcuts) { shortcut in
                                HStack {
                                    Text(shortcut.title)
                                    Spacer(minLength: 4)
                                    Text(shortcut.keys).font(ChocoTheme.font(12, weight: .medium))
                                        .foregroundStyle(Color(hex: "1E1E1F"))
                                        .frame(width: ChocoSpace.u(62), height: ChocoSpace.u(22)).background(.white, in: RoundedRectangle(cornerRadius: 5))
                                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.15)) }
                                }.frame(height: ChocoSpace.u(36))
                                    .overlay(alignment: .bottom) { Rectangle().fill(SettingsStyle.divider).frame(height: 1) }
                            }
                            if filteredShortcuts.isEmpty {
                                Text("一致するショートカットがありません").foregroundStyle(SettingsStyle.secondary).padding(.vertical, ChocoSpace.xl)
                            }
                        }.padding(.horizontal, ChocoSpace.xl).padding(.top, ChocoSpace.md)
                    }
                }.frame(width: ChocoSpace.u(340), height: ChocoSpace.u(460)).background(SettingsStyle.button)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: ChocoSpace.u(6)) {
                        keyIllustration { Text("⌘").font(ChocoTheme.font(30, weight: .bold)).foregroundStyle(SettingsStyle.accent) }
                        keyIllustration { DesignIcon("settings-e2a54", size: 62) }
                    }.padding(.top, ChocoSpace.u(2))
                    Text("Custom Shortcuts").font(ChocoTheme.font(13, weight: .semibold)).padding(.top, ChocoSpace.u(27))
                    Text("Change shortcuts for your favorite\nactions, and even choose whether\nchoco-browser or a website takes priority.")
                        .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary).padding(.top, ChocoSpace.u(8))
                    Spacer()
                    HStack(spacing: 0) {
                        // Figma draws this one in `settings/text-disabled`.
                        Button("Reset All Shortcuts") { UnsupportedNotice.shared.show("ショートカットのリセット") }
                            .buttonStyle(SettingsButtonStyle(dimmed: true))
                        Spacer(minLength: 0)
                        Button { UnsupportedNotice.shared.show("ショートカットの書き出し") } label: {
                            DesignIcon("settings-01a0f", size: 16).frame(width: ChocoSpace.u(40), height: ChocoSpace.u(24))
                        }.buttonStyle(.plain).background(SettingsStyle.button, in: Capsule())
                            .accessibilityLabel("ショートカットのその他の操作")
                    }.frame(width: ChocoSpace.u(184)).padding(.bottom, ChocoSpace.u(9))
                }.frame(width: ChocoSpace.u(200), height: ChocoSpace.u(460), alignment: .topLeading)
            }
        }.padding(.horizontal, ChocoSpace.u(64)).padding(.top, ChocoSpace.u(20))
    }

    private var filteredShortcuts: [SettingsShortcut] { SettingsShortcut.matching(shortcutQuery) }

    private func keyIllustration<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(width: ChocoSpace.u(62), height: ChocoSpace.u(62))
            .background(Color(hex: "E5D4E5"), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "8F4791"), lineWidth: 4) }
            .accessibilityHidden(true)
    }
}
