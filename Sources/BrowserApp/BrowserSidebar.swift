import BrowserCore
import SwiftUI
import UniformTypeIdentifiers

struct BrowserSidebar: View {
    @Bindable var model: AppModel
    @State private var collapsedFolders: Set<UUID> = []
    @State private var pinnedCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { model.send(.toggleSidebar) } label: { Image(systemName: "sidebar.left") }
                    .help("サイドバーを隠す (⌘S)")
            }.buttonStyle(.borderless).padding(.horizontal, 16).frame(height: 44)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    favorites
                    Button { model.showCommand(.newTab) } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("新しいタブ")
                            Spacer()
                            Text("⌘T").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 9).padding(.horizontal, 10)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityIdentifier("new-tab")
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Button { pinnedCollapsed.toggle() } label: {
                                Label("固定タブ", systemImage: pinnedCollapsed ? "chevron.right" : "chevron.down")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                            Spacer()
                            Button { model.editor = .folder(nil) } label: { Image(systemName: "folder.badge.plus") }
                                .buttonStyle(.borderless).help("フォルダを作成").accessibilityIdentifier("add-folder")
                        }.padding(.horizontal, 8)
                        if !pinnedCollapsed {
                            ForEach(rootFolders) { folder in folderRow(folder, depth: 0) }
                            ForEach(spaceTabs.filter { $0.isPinned && $0.folderID == nil }) { tab in tabRow(tab) }
                            if rootFolders.isEmpty && !spaceTabs.contains(where: \.isPinned) {
                                Text("タブを固定すると、ここに残ります")
                                    .font(.caption).foregroundStyle(.tertiary).padding(8)
                            }
                        }
                    }
                    Divider().opacity(0.5)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Button("すべて閉じる") { model.send(.clearToday) }
                                .font(.caption2).buttonStyle(.plain).foregroundStyle(.secondary)
                                .disabled(!spaceTabs.contains { !$0.isPinned })
                        }.padding(.horizontal, 8)
                        ForEach(spaceTabs.filter { !$0.isPinned }) { tab in tabRow(tab) }
                        if !spaceTabs.contains(where: { !$0.isPinned }) {
                            Text("いまの作業に使うタブを開きましょう")
                                .font(.caption).foregroundStyle(.tertiary).padding(8)
                        }
                    }
                }.padding(.horizontal, 10).padding(.top, 8)
            }
            bottomBar
        }
    }

    private var spaceTabs: [BrowserTab] { model.state.tabs.filter { $0.spaceID == model.state.selectedSpaceID } }
    private var rootFolders: [BrowserFolder] { model.state.folders.filter { $0.spaceID == model.state.selectedSpaceID && $0.parentID == nil } }

    private var favorites: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
            ForEach(model.state.favorites) { favorite in
                Button { model.send(.selectFavorite(favorite.id)) } label: {
                    Text(String(favorite.title.prefix(1)).uppercased())
                        .font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 43)
                        .background(.primary.opacity(model.state.selectedFavoriteID == favorite.id ? 0.14 : 0.055), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help(favorite.title)
                    .accessibilityLabel(favorite.title).accessibilityIdentifier("favorite-\(favorite.id)")
                    .contextMenu {
                        Button("編集…") { model.editor = .favorite(favorite.id) }
                        Button("削除", role: .destructive) { model.send(.deleteFavorite(favorite.id)) }
                    }
            }
            if model.state.favorites.count < 12 {
                Button { model.editor = .favorite(nil) } label: {
                    Image(systemName: "plus").foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 43)
                        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help("お気に入りを追加").accessibilityIdentifier("add-favorite")
            }
        }
    }

    private func folderRow(_ folder: BrowserFolder, depth: Int) -> AnyView {
        let children = model.state.folders.filter { $0.parentID == folder.id }
        return AnyView(VStack(alignment: .leading, spacing: 3) {
            Button {
                if !collapsedFolders.insert(folder.id).inserted { collapsedFolders.remove(folder.id) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: collapsedFolders.contains(folder.id) ? "chevron.right" : "chevron.down").font(.system(size: 9, weight: .semibold))
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text(folder.name).lineLimit(1)
                    Spacer()
                }.padding(.vertical, 7).padding(.horizontal, 8).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("folder-\(folder.id)")
                .contextMenu {
                    Button("名前を変更…") { model.editor = .renameFolder(folder.id) }
                    Button("サブフォルダを作成…") { model.editor = .folder(folder.id) }
                    Menu("移動") {
                        Button("固定タブの最上位へ") { model.send(.moveFolder(folder.id, parentID: nil, beforeID: nil)) }
                            .disabled(folder.parentID == nil)
                        ForEach(validFolderParents(for: folder)) { parent in
                            Button(folderPath(parent)) { model.send(.moveFolder(folder.id, parentID: parent.id, beforeID: nil)) }
                                .disabled(folder.parentID == parent.id)
                        }
                    }
                    Button("上へ移動") { moveFolder(folder, offset: -1) }
                        .disabled(folderSiblingIndex(folder) == 0)
                    Button("下へ移動") { moveFolder(folder, offset: 1) }
                        .disabled(folderSiblingIndex(folder) >= folderSiblings(folder).count - 1)
                    Divider()
                    Button("フォルダを削除", role: .destructive) { model.send(.deleteFolder(folder.id)) }
                }
                .dropDestination(for: String.self) { values, _ in
                    guard let string = values.first, let id = UUID(uuidString: string) else { return false }
                    model.send(.moveTab(id, spaceID: folder.spaceID, folderID: folder.id)); return true
                }
            if !collapsedFolders.contains(folder.id) {
                VStack(spacing: 3) {
                    ForEach(children) { child in folderRow(child, depth: depth + 1) }
                    ForEach(spaceTabs.filter { $0.folderID == folder.id }) { tab in tabRow(tab) }
                }.padding(.leading, 12)
            }
        })
    }

    private func folderSiblings(_ folder: BrowserFolder) -> [BrowserFolder] {
        model.state.folders.filter { $0.spaceID == folder.spaceID && $0.parentID == folder.parentID }
    }

    private func folderSiblingIndex(_ folder: BrowserFolder) -> Int {
        folderSiblings(folder).firstIndex { $0.id == folder.id } ?? 0
    }

    private func moveFolder(_ folder: BrowserFolder, offset: Int) {
        let siblings = folderSiblings(folder)
        guard let index = siblings.firstIndex(where: { $0.id == folder.id }), siblings.indices.contains(index + offset) else { return }
        let beforeID: UUID?
        if offset < 0 { beforeID = siblings[index - 1].id }
        else { beforeID = siblings.indices.contains(index + 2) ? siblings[index + 2].id : nil }
        model.send(.moveFolder(folder.id, parentID: folder.parentID, beforeID: beforeID))
    }

    private func validFolderParents(for folder: BrowserFolder) -> [BrowserFolder] {
        let folders = model.state.folders.filter { $0.spaceID == folder.spaceID }
        var excluded: Set<UUID> = [folder.id]
        var previousCount = -1
        while previousCount != excluded.count {
            previousCount = excluded.count
            for candidate in folders {
                if let parentID = candidate.parentID, excluded.contains(parentID) { excluded.insert(candidate.id) }
            }
        }
        return folders.filter { !excluded.contains($0.id) }
    }

    private func folderPath(_ folder: BrowserFolder) -> String {
        var names = [folder.name]
        var current = folder.parentID
        var visited: Set<UUID> = [folder.id]
        while let id = current, visited.insert(id).inserted,
              let parent = model.state.folders.first(where: { $0.id == id && $0.spaceID == folder.spaceID }) {
            names.insert(parent.name, at: 0)
            current = parent.parentID
        }
        return names.joined(separator: " / ")
    }

    private func tabRow(_ tab: BrowserTab) -> some View {
        HStack(spacing: 8) {
            Button { model.select(tab) } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.isPinned ? "pin" : "globe").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 16)
                    Text(tab.displayTitle).font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("select-tab-\(tab.id)")
            Button { model.send(.closeTab(tab.id)) } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .medium)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help(tab.isPinned ? "閉じる（固定は残ります）" : "アーカイブへ移動")
        }
        .padding(.horizontal, 9).padding(.vertical, 9)
        .background(.primary.opacity(isSelected(tab) ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tab.displayTitle)
        .accessibilityIdentifier("tab-\(tab.id)")
        .contextMenu { tabMenu(tab) }
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, let id = UUID(uuidString: value) else { return false }
            model.send(.moveTabBefore(id, beforeID: tab.id)); return true
        }
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        model.state.selectedTabID == tab.id || model.state.split?.leadingTabID == tab.id || model.state.split?.trailingTabID == tab.id
    }

    @ViewBuilder private func tabMenu(_ tab: BrowserTab) -> some View {
        Button("名前を変更…") { model.editor = .tabName(tab.id) }
        Button("複製") { model.send(.duplicateTab(tab.id)) }
        if tab.isPinned {
            Button("固定を解除") { model.send(.unpinTab(tab.id)) }
            Button("固定したURLに戻る") { model.send(.resetPinnedTab(tab.id)) }
            Button("固定URLを編集…") { model.editor = .pinnedURL(tab.id) }
        } else { Button("固定する") { model.send(.pinTab(tab.id)) } }
        Menu("移動") {
            ForEach(model.state.spaces) { space in
                Menu("\(space.icon) \(space.name)") {
                    Button("フォルダ外へ") { model.send(.moveTab(tab.id, spaceID: space.id, folderID: nil)) }
                    ForEach(model.state.folders.filter { $0.spaceID == space.id }) { folder in
                        Button(folder.name) { model.send(.moveTab(tab.id, spaceID: space.id, folderID: folder.id)) }
                    }
                }
            }
        }
        if let selected = model.selectedTab, selected.id != tab.id, selected.spaceID == tab.spaceID {
            Button("このタブと分割") { model.split(with: tab) }
        }
        Divider()
        Button(tab.isPinned ? "固定タブを削除" : "アーカイブへ移動", role: .destructive) {
            model.send(tab.isPinned ? .deleteTab(tab.id) : .closeTab(tab.id))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text(model.selectedSpace?.icon ?? "◉").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedSpace?.name ?? "Space").font(.system(size: 13, weight: .semibold))
                    Text(model.state.profiles.first(where: { $0.id == model.selectedSpace?.profileID })?.name ?? "")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Spaceを編集…") { model.editor = .space(model.state.selectedSpaceID) }.accessibilityIdentifier("edit-space")
                    Button("Spaceを追加…") { model.editor = .space(nil) }.accessibilityIdentifier("create-space")
                    Button("プロファイルを追加…") { model.editor = .profile }.accessibilityIdentifier("create-profile")
                    Divider()
                    Button("アーカイブ…") { model.showsArchive = true }.accessibilityIdentifier("open-archive")
                    SettingsLink { Text("設定…") }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityIdentifier("space-menu")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.state.spaces) { space in
                        Button { model.send(.selectSpace(space.id)) } label: {
                            Text(space.icon).font(.system(size: 17)).frame(width: 32, height: 30)
                                .background(model.state.selectedSpaceID == space.id ? model.tint.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        }.buttonStyle(.plain).help(space.name).accessibilityLabel("Space: \(space.name)")
                            .accessibilityIdentifier("space-\(space.id)")
                            .dropDestination(for: String.self) { values, _ in
                                guard let value = values.first, let id = UUID(uuidString: value) else { return false }
                                model.send(.moveTab(id, spaceID: space.id, folderID: nil)); return true
                            }
                    }
                    Button { model.editor = .space(nil) } label: { Image(systemName: "plus").frame(width: 28, height: 30) }.buttonStyle(.plain).help("Spaceを作成").accessibilityIdentifier("add-space")
                }
            }
        }.padding(14).background(.primary.opacity(0.025))
    }
}
