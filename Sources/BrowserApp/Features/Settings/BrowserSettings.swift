import SwiftUI

/// The native Settings scene keeps the same entrypoints and persisted preferences.
struct BrowserSettings: View {
    @Bindable var model: AppModel
    @State private var page = SettingsPage.general
    @State private var selectedProfileID: UUID?
    @State private var shortcutQuery = ""
    @State private var showsProfileEditor = false
    @State private var showsPrivacyInfo = false
    @State private var titlebarHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            SettingsToolbar(page: $page, titlebarHeight: titlebarHeight)
            Group {
                switch page {
                case .general: GeneralSettingsView(onShowProfiles: { page = .profiles })
                case .profiles:
                    ProfilesSettingsView(model: model, selectedProfileID: $selectedProfileID,
                                         onAddProfile: { showsProfileEditor = true },
                                         onShowPrivacyInfo: { showsPrivacyInfo = true })
                case .extensions: ExtensionsSettingsView(model: model)
                case .shortcuts: ShortcutsSettingsView(shortcutQuery: $shortcutQuery)
                case .advanced: AdvancedSettingsView(onShowGeneral: { page = .general })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .font(ChocoTheme.font(13))
        .foregroundStyle(SettingsStyle.text)
        .frame(width: ChocoSpace.u(684), height: ChocoSpace.u(650) - titlebarHeight)
        .background(SettingsStyle.background)
        .preferredColorScheme(.dark)
        .tint(SettingsStyle.accent)
        .background(SettingsWindowTitle(title: page.rawValue, titlebarHeight: $titlebarHeight))
        .overlay { ExtensionDialogLayer(model: model, surface: .settings, dims: true) }
        .sheet(isPresented: $showsProfileEditor) { EditorSheet(model: model, request: .profile) }
        .alert("Privacy and Security", isPresented: $showsPrivacyInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("プロファイルごとにCookieとログイン状態を分離します。データはこのMacに保存されます。同期・AI・利用状況の送信はありません。")
        }
        .onAppear { selectedProfileID = model.state.selectedProfile?.id }
    }
}
