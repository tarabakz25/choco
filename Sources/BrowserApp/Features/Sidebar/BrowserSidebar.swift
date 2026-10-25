import BrowserCore
import SwiftUI
import UniformTypeIdentifiers

/// The 200-point graphite browser sidebar, translated from the supplied Figma component.
/// All page labels, favorites and Spaces come from the user's actual local browser state.
struct BrowserSidebar: View {
    @Bindable var model: AppModel
    @State private var collapsedFolders: Set<UUID> = []
    @State private var pinnedCollapsed = false
    @State private var hoveredTabID: UUID?
    @State private var urlFieldPressed = false
    @State private var tabPresentation: SidebarTabPresentation
    @ChocoReducedMotion private var reduceMotion: Bool

    init(model: AppModel) {
        self.model = model
        _tabPresentation = State(initialValue: SidebarTabPresentation(tabs: model.state.tabs))
    }

    var body: some View {
        VStack(spacing: 6) {
            topBar
            addressField
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    favorites
                    pinnedTabs
                    clearDivider
                    newTabButton
                    VStack(spacing: 0) {
                        ForEach(presentedSpaceTabs.filter { !$0.tab.isPinned }) { item in presentedTabRow(item, bottomGap: 4) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
            versionPill
            Color.clear.frame(height: 6)
            bottomBar
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 11)
        .frame(minWidth: ChocoTheme.sidebarWidth, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(ChocoTheme.sidebar)
        .foregroundStyle(ChocoTheme.text)
        .font(ChocoTheme.font(13))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser-sidebar")
        .onAppear { tabPresentation.update(tabs: model.state.tabs, reducedMotion: reduceMotion) }
        .onChange(of: model.state.tabs) { _, tabs in tabPresentation.update(tabs: tabs, reducedMotion: reduceMotion) }
        .onChange(of: reduceMotion) { _, reduced in tabPresentation.update(tabs: model.state.tabs, reducedMotion: reduced) }
        .onDisappear { tabPresentation.cancelPending() }
    }

    private var spaceTabs: [BrowserTab] { model.state.tabs.filter { $0.spaceID == model.state.selectedSpaceID } }
    private var rootFolders: [BrowserFolder] { model.state.folders.filter { $0.spaceID == model.state.selectedSpaceID && $0.parentID == nil } }
    private var presentedSpaceTabs: [SidebarPresentedTab] { tabPresentation.rows.filter { $0.tab.spaceID == model.state.selectedSpaceID } }

    private var topBar: some View {
        HStack(spacing: 0) {
            // Native macOS controls are positioned by the window; never draw inactive lookalikes.
            Color.clear.frame(width: 52, height: 12).accessibilityHidden(true)
            Color.clear.frame(width: 10, height: 4).accessibilityHidden(true)
            Button { model.send(.toggleSidebar) } label: { DesignIcon("de36e", size: 16).opacity(0.62).frame(width: 28, height: 28) }
                .help("サイドバーを隠す (⌘S)").accessibilityLabel("サイドバーを隠す")
            Spacer(minLength: 0)
            Button { model.activeSession?.goBack() } label: { DesignIcon("687ab", size: 16).opacity(0.62).frame(width: 28, height: 28) }
                .disabled(!(model.activeSession?.canGoBack ?? false)).help("戻る (⌘[)").accessibilityLabel("戻る")
            Button { model.activeSession?.goForward() } label: { DesignIcon("caa3a", size: 16).opacity(0.62).frame(width: 28, height: 28) }
                .disabled(!(model.activeSession?.canGoForward ?? false)).help("進む (⌘])").accessibilityLabel("進む")
            Button {
                guard let session = model.activeSession else { return }
                session.isLoading ? session.stop() : session.reload()
            } label: { DesignIcon("108be", size: 16).opacity(0.62).frame(width: 28, height: 28) }
                .help(model.activeSession?.isLoading == true ? "読み込みを中止" : "再読み込み (⌘R)")
                .accessibilityLabel(model.activeSession?.isLoading == true ? "読み込みを中止" : "再読み込み")
        }
        .buttonStyle(.plain)
        .padding(.leading, 6)
        .frame(height: 28)
    }

    private var currentURL: String? {
        let address = model.activeSession?.url?.absoluteString ?? model.selectedTab?.url
        return address == "about:blank" ? nil : address
    }

    private var displayAddress: String {
        guard let address = currentURL, let url = URL(string: address) else { return "検索またはURLを入力…" }
        if let host = url.host {
            return host + (url.path == "/" ? "" : url.path)
        }
        return address
    }

    private var addressField: some View {
        HStack(spacing: 0) {
            Button { model.showCommand(.navigate) } label: {
                HStack(spacing: 6) {
                    DesignIcon("9d9ff", size: 13).opacity(0.55)
                    Text(displayAddress)
                        .font(ChocoTheme.font(13))
                        .foregroundStyle(currentURL == nil ? ChocoTheme.tertiary : ChocoTheme.secondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(URLFieldPressButtonStyle())
            .accessibilityLabel("アドレスを入力")
            .accessibilityIdentifier("current-url")
            .accessibilityValue(currentURL ?? "検索またはURLを入力")
            Button { model.showsSiteControls.toggle() } label: {
                DesignIcon("20d2c", size: 14).opacity(0.7).frame(width: 24, height: 28)
            }
            .buttonStyle(URLFieldPressButtonStyle()).help("サイトの操作")
            .accessibilityLabel("サイトの操作").accessibilityIdentifier("site-controls")
            .padding(.trailing, 3)
        }
        .frame(height: 32)
        .background(ChocoTheme.field, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.12))
                .opacity(urlFieldPressed ? 1 : 0)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: urlFieldPressed ? 0.07 : 0.23), value: urlFieldPressed)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onPreferenceChange(URLFieldPressedPreferenceKey.self) { urlFieldPressed = $0 }
        .anchorPreference(key: SiteControlsAnchorKey.self, value: .bounds) { $0 }
    }

    private var favorites: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 8), count: 3), alignment: .leading, spacing: 10) {
            ForEach(model.state.favorites) { favorite in
                Button { model.send(.selectFavorite(favorite.id)) } label: {
                    SiteIcon(url: favorite.url, size: 16)
                        .frame(width: 56, height: 38)
                        .background(model.state.selectedFavoriteID == favorite.id ? ChocoTheme.selected : ChocoTheme.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).help(favorite.title)
                .accessibilityLabel(favorite.title).accessibilityIdentifier("favorite-\(favorite.id)")
                .contextMenu {
                    Button("編集…") { model.editor = .favorite(favorite.id) }
                    Button("削除", role: .destructive) { model.send(.deleteFavorite(favorite.id)) }
                }
            }
            if model.state.favorites.count < 12 {
                Button { model.editor = .favorite(nil) } label: {
                    DesignIcon("77a3c", size: 16).opacity(0.7)
                        .frame(width: 56, height: 38)
                        .background(ChocoTheme.tile, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).help("お気に入りを追加")
                .accessibilityLabel("お気に入りを追加").accessibilityIdentifier("add-favorite")
            }
        }
        .padding(.bottom, 0)
    }

    private var pinnedTabs: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pinnedCollapsed {
                Button { pinnedCollapsed = false } label: {
                    HStack(spacing: 8) {
                        DesignIcon("9fb54", size: 12).opacity(0.6)
                        Text("固定タブ").font(ChocoTheme.font(13, weight: .medium)).foregroundStyle(ChocoTheme.secondary)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 10).frame(height: 32).contentShape(Rectangle())
                }.buttonStyle(.plain)
            } else {
                ForEach(rootFolders) { folder in folderRow(folder, depth: 0) }
                ForEach(presentedSpaceTabs.filter { $0.tab.isPinned && $0.tab.folderID == nil }) { item in presentedTabRow(item) }
            }
        }
        .contextMenu {
            Button("フォルダを作成…") { model.editor = .folder(nil) }.accessibilityIdentifier("add-folder")
            Button(pinnedCollapsed ? "固定タブを展開" : "固定タブを折りたたむ") { pinnedCollapsed.toggle() }
        }
    }

    private var clearDivider: some View {
        HStack(spacing: 6) {
            Rectangle().fill(ChocoTheme.divider).frame(height: 1)
            Button { model.send(.clearToday) } label: {
                HStack(spacing: 2) {
                    DesignIcon("d8aa1", size: 9)
                    Text("クリア").font(ChocoTheme.font(11, weight: .medium))
                }.foregroundStyle(ChocoTheme.secondary).opacity(0.75)
            }
            .buttonStyle(.plain).disabled(!spaceTabs.contains { !$0.isPinned })
            .help("Todayのタブをアーカイブへ移動").accessibilityIdentifier("clear-today")
        }.padding(.horizontal, 4).frame(height: 16)
    }

    private var newTabButton: some View {
        Button { model.showCommand(.newTab) } label: {
            HStack(spacing: 6) {
                DesignIcon("77a3c", size: 11).opacity(0.75).frame(width: 16, height: 16)
                Text("新しいタブ").font(ChocoTheme.font(13, weight: .medium))
                Spacer(minLength: 0)
            }.padding(.horizontal, 10).frame(height: 32).contentShape(Rectangle())
                .background(ChocoTheme.selected, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).help("新しいタブ (⌘T)").accessibilityIdentifier("new-tab")
    }

    private func folderRow(_ folder: BrowserFolder, depth: Int) -> AnyView {
        let children = model.state.folders.filter { $0.parentID == folder.id }
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Button {
                if !collapsedFolders.insert(folder.id).inserted { collapsedFolders.remove(folder.id) }
            } label: {
                HStack(spacing: 8) {
                    DesignIcon("9fb54", size: 12).opacity(0.6)
                        .rotationEffect(.degrees(collapsedFolders.contains(folder.id) ? 0 : 90))
                    Text(folder.name).font(ChocoTheme.font(13, weight: .medium)).foregroundStyle(ChocoTheme.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 10).frame(height: 32).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("folder-\(folder.id)")
                .contextMenu {
                    Button("名前を変更…") { model.editor = .renameFolder(folder.id) }
                    Button("サブフォルダを作成…") { model.editor = .folder(folder.id) }
                    Menu("移動") {
                        Button("固定タブの最上位へ") { model.send(.moveFolder(folder.id, parentID: nil, beforeID: nil)) }.disabled(folder.parentID == nil)
                        ForEach(validFolderParents(for: folder)) { parent in
                            Button(folderPath(parent)) { model.send(.moveFolder(folder.id, parentID: parent.id, beforeID: nil)) }.disabled(folder.parentID == parent.id)
                        }
                    }
                    Button("上へ移動") { moveFolder(folder, offset: -1) }.disabled(folderSiblingIndex(folder) == 0)
                    Button("下へ移動") { moveFolder(folder, offset: 1) }.disabled(folderSiblingIndex(folder) >= folderSiblings(folder).count - 1)
                    Divider()
                    Button("フォルダを削除", role: .destructive) { model.send(.deleteFolder(folder.id)) }
                }
                .dropDestination(for: String.self) { values, _ in
                    guard let string = values.first, let id = UUID(uuidString: string) else { return false }
                    model.send(.moveTab(id, spaceID: folder.spaceID, folderID: folder.id)); return true
                }
            if !collapsedFolders.contains(folder.id) {
                VStack(spacing: 0) {
                    ForEach(children) { child in folderRow(child, depth: depth + 1) }
                    ForEach(presentedSpaceTabs.filter { $0.tab.folderID == folder.id }) { item in presentedTabRow(item) }
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

    private func presentedTabRow(_ item: SidebarPresentedTab, bottomGap: CGFloat = 0) -> some View {
        tabRow(item.tab)
            .allowsHitTesting(!item.isRetiring)
            .accessibilityHidden(item.isRetiring)
            .modifier(TabRowMotion(progress: item.progress, bottomGap: bottomGap, reducedMotion: reduceMotion))
    }

    private func tabRow(_ tab: BrowserTab) -> some View {
        HStack(spacing: 0) {
            Button { model.select(tab) } label: {
                HStack(spacing: 6) {
                    SiteIcon(url: tab.url, size: 16)
                    Text(tab.displayTitle).font(ChocoTheme.font(13, weight: .medium)).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 10).padding(.trailing, 6).frame(height: 32)
                .background(isSelected(tab) ? ChocoTheme.selected : hoveredTabID == tab.id ? ChocoTheme.tile : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("select-tab-\(tab.id)")
        }
        .onHover { hoveredTabID = $0 ? tab.id : nil }
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

    private var versionPill: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return Text(version.map { "choco \($0) · α" } ?? "choco · α")
            .font(ChocoTheme.font(11, weight: .semibold))
            .frame(maxWidth: .infinity).frame(height: 22)
            .background(ChocoTheme.field, in: Capsule())
            .accessibilityIdentifier("app-version")
    }

    private var bottomBar: some View {
        HStack(spacing: 2) {
            Button { model.showsArchive = true } label: {
                DesignIcon("e1841", size: 16).opacity(0.7).frame(width: 26, height: 26)
            }.buttonStyle(.plain).help("ライブラリ · アーカイブ").accessibilityLabel("ライブラリ").accessibilityIdentifier("open-archive")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(model.state.spaces) { space in
                        Button { model.send(.selectSpace(space.id)) } label: {
                            SpaceIcon(space.icon, size: 16).frame(width: 24, height: 26)
                                .background(model.state.selectedSpaceID == space.id ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(alignment: .bottom) {
                                    if model.state.selectedSpaceID == space.id {
                                        Capsule().fill(model.tint).frame(width: 12, height: 2).padding(.bottom, 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain).help(space.name).accessibilityLabel("Space: \(space.name)")
                        .accessibilityIdentifier("space-\(space.id)")
                        .dropDestination(for: String.self) { values, _ in
                            guard let value = values.first, let id = UUID(uuidString: value) else { return false }
                            model.send(.moveTab(id, spaceID: space.id, folderID: nil)); return true
                        }
                    }
                }
            }.frame(height: 26)
            Menu {
                Text("\(model.selectedSpace?.name ?? "Space") · \(model.state.selectedProfile?.name ?? "")")
                Divider()
                Button("Spaceを編集…") { model.editor = .space(model.state.selectedSpaceID) }.accessibilityIdentifier("edit-space")
                Button("Spaceを追加…") { model.editor = .space(nil) }.accessibilityIdentifier("create-space")
                Button("プロファイルを追加…") { model.editor = .profile }.accessibilityIdentifier("create-profile")
                Button("フォルダを作成…") { model.editor = .folder(nil) }.accessibilityIdentifier("add-folder")
                Button(pinnedCollapsed ? "固定タブを展開" : "固定タブを折りたたむ") { pinnedCollapsed.toggle() }
                Divider()
                Button("アーカイブ…") { model.showsArchive = true }
                SettingsLink { Text("設定…") }
            } label: { DesignIcon("a3077", size: 16).opacity(0.7).frame(width: 26, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Spaceとプロファイル").accessibilityLabel("Spaceとプロファイル").accessibilityIdentifier("space-menu")
            Button { model.editor = .space(nil) } label: {
                DesignIcon("77a3c", size: 16).opacity(0.7).frame(width: 26, height: 26)
            }.buttonStyle(.plain).help("Spaceを作成").accessibilityLabel("Spaceを作成").accessibilityIdentifier("add-space")
        }.frame(height: 26)
    }
}

/// Observes the native button press without adding a competing mouse gesture.
private struct URLFieldPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.preference(key: URLFieldPressedPreferenceKey.self, value: configuration.isPressed)
    }
}

private struct URLFieldPressedPreferenceKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = nextValue() || value }
}

/// Drives the rendered row itself, including its intermediate insertion/removal
/// frames. Diagnostics are opt-in and contain no title, address, or tab identity.
private struct TabRowMotion: AnimatableModifier {
    nonisolated var progress: CGFloat
    let bottomGap: CGFloat
    let reducedMotion: Bool
    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let phase = min(1, max(0, progress))
        MotionDiagnostics.record("tab-row", value: Double(phase), x: Double(-8 * (1 - phase)), reducedMotion: reducedMotion)
        return content
            .frame(height: (32 + bottomGap) * phase, alignment: .top)
            .clipped()
            .opacity(Double(phase))
            .offset(x: -8 * (1 - phase))
    }
}
