import BrowserCore
import BrowserRuntime
import SwiftUI

enum EditorRequest: Identifiable {
    case tabName(UUID), pinnedURL(UUID), folder(UUID?), renameFolder(UUID), space(UUID?), profile, favorite(UUID?)
    var id: String { String(describing: self) }
}

struct EditorSheet: View {
    @Bindable var model: AppModel
    let request: EditorRequest
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var icon = "◉"
    @State private var color = "8D83C9"
    @State private var profileID: UUID?
    @State private var error: String?
    @FocusState private var focused: Bool
    private let colors = ["8D83C9", "6F9C91", "C08A79", "719CC0", "A38B60", "B87594"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(heading).font(.title2.weight(.semibold))
            Form {
                TextField(isURLOnly ? "固定URL" : "名前", text: isURLOnly ? $address : $name)
                    .focused($focused).accessibilityIdentifier("editor-name").onSubmit { save() }
                if case .space = request {
                    TextField("アイコン", text: $icon)
                    Picker("プロファイル", selection: $profileID) {
                        ForEach(model.state.profiles) { profile in Text(profile.name).tag(Optional(profile.id)) }
                    }.accessibilityIdentifier("profile-picker")
                    HStack {
                        Text("Spaceの色")
                        Spacer()
                        ForEach(colors, id: \.self) { candidate in
                            Button { color = candidate } label: {
                                Circle().fill(Color(hex: candidate)).frame(width: 24, height: 24)
                                    .overlay { if color == candidate { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            }.buttonStyle(.plain).accessibilityLabel("色 \(candidate)")
                        }
                    }
                    Text("同じプロファイルのSpaceはログイン状態を共有します。変更すると、そのSpaceのタブを別のログイン状態で開き直します。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if case .favorite = request { TextField("URL", text: $address).accessibilityIdentifier("editor-url") }
            }.formStyle(.grouped)
            if let error { Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).accessibilityIdentifier("editor-save")
            }
        }.padding(ChocoSpace.xl).frame(width: 470)
            .onAppear { load(); focused = true }
    }

    private var isURLOnly: Bool { if case .pinnedURL = request { return true }; return false }
    private var heading: String {
        switch request {
        case .tabName: "タブの名前"
        case .pinnedURL: "固定URLを編集"
        case .folder: "フォルダを作成"
        case .renameFolder: "フォルダの名前"
        case .space(let id): id == nil ? "Spaceを作成" : "Spaceを編集"
        case .profile: "プロファイルを作成"
        case .favorite(let id): id == nil ? "お気に入りを追加" : "お気に入りを編集"
        }
    }

    private func load() {
        profileID = model.selectedSpace?.profileID ?? model.state.profiles.first?.id
        switch request {
        case .tabName(let id): name = model.state.tabs.first(where: { $0.id == id })?.displayTitle ?? ""
        case .pinnedURL(let id): address = model.state.tabs.first(where: { $0.id == id })?.pinnedURL ?? ""
        case .renameFolder(let id): name = model.state.folders.first(where: { $0.id == id })?.name ?? ""
        case .space(let id):
            if let space = model.state.spaces.first(where: { $0.id == id }) { name = space.name; icon = space.icon; color = space.colorHex; profileID = space.profileID }
        case .favorite(let id):
            if let favorite = model.state.favorites.first(where: { $0.id == id }) { name = favorite.title; address = favorite.url }
            else { name = model.activeSession?.title ?? ""; address = model.activeSession?.url?.absoluteString ?? "" }
        default: break
        }
    }

    private func resolvedAddress() -> String? {
        guard let url = AddressResolver.resolve(address), !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "有効なURLを入力してください。"; return nil }
        return url.absoluteString
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isURLOnly && cleanName.isEmpty { error = "名前を入力してください。"; return }
        switch request {
        case .tabName(let id): model.send(.renameTab(id, cleanName))
        case .pinnedURL(let id): guard let url = resolvedAddress() else { return }; model.send(.setPinnedURL(id, url))
        case .folder(let parent): model.send(.createFolder(name: cleanName, parentID: parent))
        case .renameFolder(let id): model.send(.renameFolder(id, cleanName))
        case .space(let id):
            guard let profileID else { return }
            if let id { model.send(.updateSpace(id, name: cleanName, icon: icon.isEmpty ? "◉" : icon, colorHex: color, profileID: profileID)) }
            else { model.send(.createSpace(name: cleanName, icon: icon.isEmpty ? "◉" : icon, colorHex: color, profileID: profileID)) }
        case .profile: model.send(.createProfile(name: cleanName))
        case .favorite(let id):
            guard let url = resolvedAddress() else { return }
            if let id { model.send(.updateFavorite(id, title: cleanName, url: url)) }
            else { model.send(.createFavorite(title: cleanName, url: url)) }
        }
        dismiss()
    }
}
