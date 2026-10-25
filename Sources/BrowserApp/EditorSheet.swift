import BrowserLocalization
import BrowserCore
import BrowserRuntime
import SwiftUI

struct EditorSheet: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var language = AppLanguage.current.rawValue
    private var l10n: Localizer { Localizer(language: AppLanguage(rawValue: language) ?? .current) }
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
                TextField(isURLOnly ? l10n.text("Pinned URL") : l10n.text("Name"), text: isURLOnly ? $address : $name)
                    .focused($focused).accessibilityIdentifier("editor-name").onSubmit { save() }
                if case .space = request {
                    TextField(l10n.text("Icon"), text: $icon)
                    Picker(l10n.text("Profiles"), selection: $profileID) {
                        ForEach(model.state.profiles) { profile in Text(profile.name).tag(Optional(profile.id)) }
                    }.accessibilityIdentifier("profile-picker")
                    HStack {
                        Text(l10n.text("Space Color"))
                        Spacer()
                        ForEach(colors, id: \.self) { candidate in
                            Button { color = candidate } label: {
                                Circle().fill(Color(hex: candidate)).frame(width: 24, height: 24)
                                    .overlay { if color == candidate { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            }.buttonStyle(.plain).accessibilityLabel(l10n.format("Color %@", candidate))
                        }
                    }
                    Text(l10n.text("Spaces with the same profile share logins. Changing the profile reopens this Space’s tabs with separate logins."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if case .favorite = request { TextField("URL", text: $address).accessibilityIdentifier("editor-url") }
            }.formStyle(.grouped)
            if let error { Label(l10n.text(error), systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(l10n.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(l10n.text("Save")) { save() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).accessibilityIdentifier("editor-save")
            }
        }.padding(24).frame(width: 470)
            .onAppear { load(); focused = true }
    }

    private var isURLOnly: Bool { if case .pinnedURL = request { return true }; return false }
    private var heading: String {
        switch request {
        case .tabName: l10n.text("Tab Name")
        case .pinnedURL: l10n.text("Edit Pinned URL")
        case .folder: l10n.text("Create Folder")
        case .renameFolder: l10n.text("Folder Name")
        case .space(let id): id == nil ? l10n.text("Create Space") : l10n.text("Edit Space")
        case .profile: l10n.text("Create Profile")
        case .favorite(let id): id == nil ? l10n.text("Add Favorite") : l10n.text("Edit Favorite")
        }
    }

    private func load() {
        profileID = model.selectedSpace?.profileID ?? model.state.profiles.first?.id
        switch request {
        case .tabName(let id): name = model.state.tabs.first(where: { $0.id == id })?.localizedTitle(using: l10n) ?? ""
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
        guard let url = AddressResolver.resolve(address), !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Enter a valid URL."; return nil }
        return url.absoluteString
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isURLOnly && cleanName.isEmpty { error = "Enter a name."; return }
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

struct ArchiveSheet: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var language = AppLanguage.current.rawValue
    private var l10n: Localizer { Localizer(language: AppLanguage(rawValue: language) ?? .current) }
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(l10n.text("Archive")).font(.title2.weight(.semibold)); Spacer(); Button(l10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction) }
            TextField(l10n.text("Search closed tabs"), text: $search).textFieldStyle(.roundedBorder)
            if model.state.archive.isEmpty {
                ContentUnavailableView(l10n.text("No Closed Tabs"), systemImage: "archivebox", description: Text(l10n.text("Close a Today tab to restore it here.")))
            } else {
                List(model.state.archive.filter { search.isEmpty || "\($0.tab.localizedTitle(using: l10n)) \($0.tab.url)".localizedCaseInsensitiveContains(search) }) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.tab.localizedTitle(using: l10n)).lineLimit(1)
                            Text(entry.tab.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(entry.archivedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                        Button(l10n.text("Restore")) { model.send(.restoreArchive(entry.id)); dismiss() }
                    }.padding(.vertical, 4)
                }.listStyle(.inset)
            }
        }.padding(24).frame(width: 660, height: 460)
    }
}
