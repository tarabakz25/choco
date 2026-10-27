import AppKit
import BrowserCore
import SwiftUI
import UniformTypeIdentifiers

/// The 12.5rem (200pt) graphite browser sidebar, translated from the supplied Figma component.
/// All page labels, favorites and Spaces come from the user's actual local browser state.
struct BrowserSidebar: View {
    @Bindable var model: AppModel
    @State private var collapsedFolders: Set<UUID> = []
    @State private var pinnedCollapsed = false
    @State private var urlFieldPressed = false
    @State private var urlFieldHovered = false
    @State private var clearHovered = false
    @AppStorage("choco.hidesEmptyFavoritesHint") private var hidesFavoritesHint = false
    @State private var favoritesDropTargeted = false
    @State private var pinnedDropTargeted = false
    @State private var tabPresentation: SidebarTabPresentation
    @State private var slide: SpaceSlide
    @State private var slideTask: Task<Void, Never>?
    @Environment(\.spaceTheme) private var theme
    @ChocoReducedMotion private var reduceMotion: Bool

    init(model: AppModel) {
        self.model = model
        _tabPresentation = State(initialValue: SidebarTabPresentation(tabs: model.state.tabs))
        _slide = State(initialValue: SpaceSlide(current: model.state.selectedSpaceID))
    }

    var body: some View {
        VStack(spacing: ChocoSpace.u(6)) {
            topBar
            addressField
            // Vertical input is only taken when the list overflows; otherwise it must not even rubber-band.
            ScrollView(.vertical, showsIndicators: false) { spaceLists }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(maxHeight: .infinity)
            Color.clear.frame(height: ChocoSpace.u(6))
            bottomBar
        }
        .padding(.horizontal, ChocoSpace.u(8))
        // The row is centred 20pt below the top edge, level with the traffic lights (see `TrafficLightInset`).
        .padding(.top, 6)
        .padding(.bottom, ChocoSpace.u(11))
        .frame(minWidth: ChocoTheme.sidebarWidth, maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(theme.sidebar)
        .background(SpaceSwipeArea(onChange: { swipeChanged($0) }, onEnd: { swipeEnded($0, velocity: $1) }))
        .foregroundStyle(ChocoTheme.text)
        .font(ChocoTheme.font(13))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser-sidebar")
        .onAppear { tabPresentation.update(tabs: model.state.tabs, reducedMotion: reduceMotion) }
        .onChange(of: model.state.tabs) { _, tabs in tabPresentation.update(tabs: tabs, reducedMotion: reduceMotion) }
        .onChange(of: reduceMotion) { _, reduced in tabPresentation.update(tabs: model.state.tabs, reducedMotion: reduced) }
        .onChange(of: model.state.selectedSpaceID) { old, new in beginSpaceSlide(from: old, to: new) }
        .onDisappear { tabPresentation.cancelPending(); slideTask?.cancel(); slide = SpaceSlide(current: model.state.selectedSpaceID) }
    }

    private func spaceTabs(in spaceID: UUID) -> [BrowserTab] { model.state.tabs.filter { $0.spaceID == spaceID } }
    private func rootFolders(in spaceID: UUID) -> [BrowserFolder] { model.state.folders.filter { $0.spaceID == spaceID && $0.parentID == nil } }
    private func presentedSpaceTabs(in spaceID: UUID) -> [SidebarPresentedTab] { tabPresentation.rows.filter { $0.tab.spaceID == spaceID } }

    /// How far a list moves to clear the 184pt column.
    private static var listTravel: CGFloat { ChocoTheme.sidebarWidth - 2 * ChocoSpace.u(8) }

    /// Figma `Space Lists` (163:7449): switching Space slides the old list out and the new one in on the 320 ms spring,
    /// the old one fading over 160 ms and the new one over 180 ms, 40 ms in. The list is laid out per Space id, so the
    /// outgoing list keeps showing its own Space instead of following the selection.
    private var spaceLists: some View {
        let travel = Self.listTravel
        return ZStack(alignment: .topLeading) {
            if let outgoing = slide.outgoing {
                spaceList(outgoing)
                    .offset(x: -slide.direction * travel * slide.progress)
                    .opacity(slide.outgoingOpacity)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            spaceList(slide.current)
                .offset(x: slide.direction * travel * (1 - slide.progress) + slide.rubber)
                .opacity(slide.incomingOpacity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func spaceList(_ spaceID: UUID) -> some View {
        let isEmpty = isSpaceEmpty(spaceID)
        return VStack(alignment: .leading, spacing: ChocoSpace.u(6)) {
            // Figma's Space lists (162:7390) lead with the Space name; the empty Space labels itself below.
            if !isEmpty { spaceNameLabel(spaceID) }
            if model.state.favorites.isEmpty && !hidesFavoritesHint { favoritesEmpty } else { favorites }
            if isEmpty { spaceNameLabel(spaceID) }
            pinnedTabs(in: spaceID)
            if !isEmpty { clearDivider(in: spaceID) }
            newTabButton
            VStack(spacing: 0) {
                ForEach(presentedSpaceTabs(in: spaceID).filter { !$0.tab.isPinned }) { item in presentedTabRow(item, bottomGap: ChocoSpace.u(4)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// A sideways two-finger swipe over the sidebar drags the lists with the fingers: the neighbouring Space slides in
    /// behind the current one, and pulling past the first or last Space meets resistance.
    private func swipeChanged(_ offset: CGFloat) {
        slideTask?.cancel()
        if !slide.dragging, slide.outgoing != nil {
            // A switch still settling is finished on the spot (its spring is all but done within ~100 ms), so a quick
            // second swipe starts from rest instead of being ignored.
            model.clearSpaceBlend()
            var immediate = Transaction(); immediate.disablesAnimations = true
            withTransaction(immediate) { slide = SpaceSlide(current: model.state.selectedSpaceID) }
        }
        let ids = model.state.spaces.map(\.id)
        let selected = model.state.selectedSpaceID
        let step = offset < 0 ? 1 : -1
        var immediate = Transaction(); immediate.disablesAnimations = true
        withTransaction(immediate) {
            guard let index = ids.firstIndex(of: selected), ids.indices.contains(index + step) else {
                slide = SpaceSlide(current: selected, rubber: SpaceSwipeRecognizer.rubberBand(offset, travel: Self.listTravel), dragging: true)
                model.clearSpaceBlend()
                return
            }
            let progress = min(1, abs(offset) / Self.listTravel)
            slide = SpaceSlide(current: ids[index + step], outgoing: selected, direction: CGFloat(step), progress: progress,
                               outgoingOpacity: 1 - min(1, progress / 0.5), incomingOpacity: min(1, max(0, (progress - 0.12) / 0.5)),
                               dragging: true)
            // The window colour travels with the fingers too.
            model.dragSpaceBlend(from: selected, to: ids[index + step], progress: progress)
        }
    }

    /// The fingers lifted: finish the switch from where the lists are, or settle back.
    private func swipeEnded(_ offset: CGFloat, velocity: CGFloat) {
        guard slide.dragging else { return }
        slideTask?.cancel()
        let selected = model.state.selectedSpaceID
        if let outgoing = slide.outgoing, outgoing == selected,
           SpaceSwipeRecognizer.commits(offset: offset, velocity: velocity, travel: Self.listTravel) {
            let target = slide.current
            slide.dragging = false
            if reduceMotion {
                slide = SpaceSlide(current: target)
            } else {
                slideTask = Task { @MainActor in
                    // A quick flick lifts within the frame that drew its first move: let that frame land so the
                    // animation has somewhere to start from instead of the lists jumping straight to the end.
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                    let remaining = Self.listTravel * (1 - slide.progress)
                    withAnimation(ChocoMotion.spaceSettle(distance: remaining, maxSpeed: SpaceSwipeRecognizer.maxSpeed)) { slide.progress = 1 }
                    withAnimation(ChocoMotion.spaceListFadeOut) { slide.outgoingOpacity = 0 }
                    withAnimation(ChocoMotion.spaceListFadeIn) { slide.incomingOpacity = 1 }
                    do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
                    slide.outgoing = nil
                }
            }
            // The selection catches up; `beginSpaceSlide` and the colour blend see the switch already under way.
            model.settleSpaceBlend(to: 1)
            model.send(.selectSpace(target))
            return
        }
        let settled = SpaceSlide(current: selected)
        model.settleSpaceBlend(to: 0)
        guard !reduceMotion else { slide = settled; return }
        let hasNeighbour = slide.outgoing != nil
        slide.dragging = false
        slideTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
            let pulled = hasNeighbour ? Self.listTravel * slide.progress : abs(slide.rubber)
            withAnimation(ChocoMotion.spaceSettle(distance: pulled, maxSpeed: SpaceSwipeRecognizer.maxSpeed)) {
                slide.rubber = 0
                if hasNeighbour { slide.progress = 0 }
            }
            // Only a neighbouring list fades back. At the first or last Space the one list on show is `incoming`, and
            // fading it would make the list vanish and pop back after the pull.
            if hasNeighbour {
                withAnimation(ChocoMotion.spaceListFadeOut) { slide.outgoingOpacity = 1; slide.incomingOpacity = 0 }
            }
            do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
            var immediate = Transaction(); immediate.disablesAnimations = true
            withTransaction(immediate) { slide = settled }
        }
    }

    /// Follows a change of the selected Space: the lists restart from the edge on the next frame and animate in.
    private func beginSpaceSlide(from old: UUID, to new: UUID) {
        // A swipe already carried the lists across.
        if slide.current == new, slide.outgoing == old { return }
        slideTask?.cancel()
        guard !reduceMotion, old != new else { slide = SpaceSlide(current: new); return }
        let spaces = model.state.spaces.map(\.id)
        let direction: CGFloat = (spaces.firstIndex(of: new) ?? 0) >= (spaces.firstIndex(of: old) ?? 0) ? 1 : -1
        var immediate = Transaction(); immediate.disablesAnimations = true
        withTransaction(immediate) {
            slide = SpaceSlide(current: new, outgoing: old, direction: direction, progress: 0, outgoingOpacity: 1, incomingOpacity: 0)
        }
        slideTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            withAnimation(ChocoMotion.space) { slide.progress = 1 }
            withAnimation(ChocoMotion.spaceListFadeOut) { slide.outgoingOpacity = 0 }
            withAnimation(ChocoMotion.spaceListFadeIn) { slide.incomingOpacity = 1 }
            do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
            slide.outgoing = nil
        }
    }

    /// Distance from the sidebar's leading edge to the first control, clear of the native traffic lights.
    private static let controlsInset: CGFloat = 76

    private var topBar: some View {
        HStack(spacing: 0) {
            // Native macOS controls are positioned by the window; never draw inactive lookalikes.
            Color.clear.frame(width: Self.controlsInset - ChocoSpace.u(8) - ChocoSpace.u(6), height: 12).accessibilityHidden(true)
            Button { model.send(.toggleSidebar) } label: { DesignIcon("de36e", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .help("サイドバーを隠す (⌘S)").accessibilityLabel("サイドバーを隠す")
            Spacer(minLength: 0)
            Button { model.activeSession?.goBack() } label: { DesignIcon("687ab", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .disabled(!(model.activeSession?.canGoBack ?? false)).help("戻る (⌘[)").accessibilityLabel("戻る")
            Button { model.activeSession?.goForward() } label: { DesignIcon("caa3a", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .disabled(!(model.activeSession?.canGoForward ?? false)).help("進む (⌘])").accessibilityLabel("進む")
            Button {
                guard let session = model.activeSession else { return }
                session.isLoading ? session.stop() : session.reload()
            } label: { DesignIcon("108be", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .help(model.activeSession?.isLoading == true ? "読み込みを中止" : "再読み込み (⌘R)")
                .accessibilityLabel(model.activeSession?.isLoading == true ? "読み込みを中止" : "再読み込み")
        }
        .buttonStyle(ChocoPressStyle(disabledOpacity: 0.35))
        .padding(.leading, ChocoSpace.u(6))
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

    /// Figma `Sidebar URL Field`: "Search" (placeholder, no controls) while there is no page, "URL" (address, link and
    /// site-controls tile) once one is open. Hovering or pressing lifts the fill from 7% to 12%.
    private var addressField: some View {
        HStack(spacing: 0) {
            Button { model.showCommand(.navigate) } label: {
                HStack(spacing: ChocoSpace.u(6)) {
                    if currentURL == nil { DesignIcon("9d9ff", size: 13).opacity(0.55) }
                    Text(displayAddress)
                        .font(ChocoTheme.font(13))
                        .foregroundStyle(currentURL == nil ? ChocoTheme.tertiary : ChocoTheme.secondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.leading, ChocoSpace.u(10))
                .frame(maxWidth: .infinity, minHeight: ChocoSpace.u(32), alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(URLFieldPressButtonStyle())
            .accessibilityLabel("アドレスを入力")
            .accessibilityIdentifier("current-url")
            .accessibilityValue(currentURL ?? "検索またはURLを入力")
            if let address = currentURL {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                } label: {
                    DesignIcon("d4cd0", size: 14).opacity(0.55).frame(width: ChocoSpace.u(20), height: ChocoSpace.u(28))
                }
                .buttonStyle(ChocoPressStyle(radius: 5)).help("URLをコピー").accessibilityLabel("URLをコピー")
                .accessibilityIdentifier("copy-url")
                Button { model.showsSiteControls.toggle() } label: {
                    DesignIcon("20d2c", size: 12).opacity(0.9).frame(width: ChocoSpace.u(20), height: ChocoSpace.u(20))
                        .frame(width: ChocoSpace.u(24), height: ChocoSpace.u(28))
                }
                .buttonStyle(SiteControlsButtonStyle(isActive: model.showsSiteControls)).help("サイトの操作")
                .accessibilityLabel("サイトの操作").accessibilityIdentifier("site-controls")
                .accessibilityAddTraits(model.showsSiteControls ? .isSelected : [])
                .padding(.trailing, ChocoSpace.u(4))
            }
        }
        .frame(height: ChocoSpace.u(32))
        .background(urlFieldPressed || urlFieldHovered ? ChocoTheme.selected : theme.field, in: RoundedRectangle(cornerRadius: 8))
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: urlFieldPressed ? 0.07 : 0.23), value: urlFieldPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: urlFieldHovered)
        .onHover { urlFieldHovered = $0 }
        .onPreferenceChange(URLFieldPressedPreferenceKey.self) { urlFieldPressed = $0 }
        .anchorPreference(key: SiteControlsAnchorKey.self, value: .bounds) { $0 }
    }

    /// No tabs, folders or pinned items in the current Space: Figma 157:7042 drops the divider and selection tint.
    private func isSpaceEmpty(_ spaceID: UUID) -> Bool { spaceTabs(in: spaceID).isEmpty && rootFolders(in: spaceID).isEmpty }

    /// Figma `Favorites Empty` (156:1528): dashed 10pt-radius box, 16pt star badge, two centered lines.
    private var favoritesEmpty: some View {
        VStack(spacing: ChocoSpace.xxs) {
            DesignIcon("f625c", size: 16)
            Text("ドラッグしてお気に入りに追加").font(ChocoTheme.font(10.5, weight: .semibold))
            Text("よく使うサイトやアプリをすぐ開けます")
                .font(ChocoTheme.font(10)).foregroundStyle(ChocoTheme.secondary)
                .multilineTextAlignment(.center).lineSpacing(0).fixedSize(horizontal: false, vertical: true)
                .frame(width: ChocoSpace.u(124))
        }
        .padding(.top, ChocoSpace.md).padding(.bottom, ChocoSpace.sm).padding(.horizontal, ChocoSpace.md)
        .frame(maxWidth: .infinity)
        .background(theme.favoritesEmpty(highlighted: favoritesDropTargeted), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .overlay(alignment: .topTrailing) {
            Button { hidesFavoritesHint = true } label: {
                DesignIcon("77a3c", size: 11).rotationEffect(.degrees(45)).frame(width: ChocoSpace.u(20), height: ChocoSpace.u(20))
            }
            .buttonStyle(ChocoPressStyle(radius: 5)).padding(.top, 3).padding(.trailing, 3)
            .help("ヒントを閉じる").accessibilityLabel("ヒントを閉じる")
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [.plainText], delegate: FavoriteDropDelegate(model: model, tracksSlot: false, animation: reduceMotion ? nil : ChocoMotion.favoriteReflow, targeted: $favoritesDropTargeted))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ドラッグしてお気に入りに追加")
        .accessibilityIdentifier("favorites-empty")
    }

    /// Figma `Space Name` (156:1704): 28pt row labelling an otherwise empty Space.
    private func spaceNameLabel(_ spaceID: UUID) -> some View {
        Text(model.state.spaces.first { $0.id == spaceID }?.name ?? "")
            .font(ChocoTheme.font(11, weight: .semibold)).foregroundStyle(theme.label).lineLimit(1)
            .padding(.horizontal, ChocoSpace.u(10)).frame(maxWidth: .infinity, alignment: .leading).frame(height: ChocoSpace.u(28))
            .accessibilityIdentifier("space-name")
    }

    private var favoriteCells: [FavoriteCell] {
        var cells = model.state.favorites.map(FavoriteCell.favorite)
        if let index = model.favoriteDropIndex { cells.insert(.placeholder, at: min(max(0, index), cells.count)) }
        return cells
    }

    private var favorites: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(FavoriteDropDelegate.tileWidth), spacing: FavoriteDropDelegate.columnGap), count: 3), alignment: .leading, spacing: FavoriteDropDelegate.rowGap) {
            ForEach(favoriteCells) { cell in
                switch cell {
                case .favorite(let favorite):
                    Button { model.send(.selectFavorite(favorite.id)) } label: {
                        SiteIcon(url: favorite.url, size: 14)
                            .frame(width: ChocoSpace.u(56), height: ChocoSpace.u(40))
                    }
                    .buttonStyle(FavoriteTileStyle(isSelected: model.state.selectedFavoriteID == favorite.id)).help(favorite.title)
                    .accessibilityLabel(favorite.title).accessibilityIdentifier("favorite-\(favorite.id)")
                    .contextMenu {
                        Button("編集…") { model.editor = .favorite(favorite.id) }
                        Button("削除", role: .destructive) { model.send(.deleteFavorite(favorite.id)) }
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                case .placeholder:
                    // Where the dragged tab will land.
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .background(ChocoTheme.tile.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: ChocoSpace.u(56), height: ChocoSpace.u(40))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
        }
        .animation(reduceMotion ? nil : ChocoMotion.favoriteReflow, value: favoriteCells)
        // The delegate reads the pointer in the grid's own space, so it sits before any padding.
        .onDrop(of: [.plainText], delegate: FavoriteDropDelegate(model: model, tracksSlot: true, animation: reduceMotion ? nil : ChocoMotion.favoriteReflow, targeted: $favoritesDropTargeted))
        // Figma leaves 12pt between the tiles and the folder row; the stack already adds 6.
        .padding(.bottom, ChocoSpace.u(6))
    }

    private func pinnedTabs(in spaceID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if pinnedCollapsed {
                Button { pinnedCollapsed = false } label: {
                    HStack(spacing: ChocoSpace.sm) {
                        DesignIcon("9fb54", size: 12).opacity(0.6)
                        Text("固定タブ").font(ChocoTheme.font(13, weight: .medium)).foregroundStyle(ChocoTheme.secondary)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(32)).contentShape(Rectangle())
                }.buttonStyle(ChocoPressStyle(radius: 8))
            } else {
                ForEach(rootFolders(in: spaceID)) { folder in folderRow(folder, depth: 0) }
                ForEach(presentedSpaceTabs(in: spaceID).filter { $0.tab.isPinned && $0.tab.folderID == nil }) { item in presentedTabRow(item) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            // With nothing pinned yet there is no row to drop on. The zone floats over the divider while a tab
            // is dragged, so the list underneath never shifts.
            if draggedTabCanPin && pinnedIsEmpty(in: spaceID) {
                pinDropHint
                    .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    .tabDrop(model: model, targeted: $pinnedDropTargeted) { id in
                        model.send(.pinTab(id)); return true
                    }
            }
        }
        .animation(reduceMotion ? nil : ChocoMotion.favoriteReflow, value: draggedTabCanPin)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(pinnedDropTargeted ? 0.1 : 0)).allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .tabDrop(model: model, targeted: $pinnedDropTargeted) { id in
            guard let tab = model.state.tabs.first(where: { $0.id == id }) else { return false }
            if tab.isPinned { model.send(.moveTab(id, spaceID: tab.spaceID, folderID: nil)) }
            else { model.send(.pinTab(id)) }
            return true
        }
        .contextMenu {
            Button("フォルダを作成…") { model.editor = .folder(nil) }.accessibilityIdentifier("add-folder")
            Button(pinnedCollapsed ? "固定タブを展開" : "固定タブを折りたたむ") { pinnedCollapsed.toggle() }
        }
    }

    private func pinnedIsEmpty(in spaceID: UUID) -> Bool { rootFolders(in: spaceID).isEmpty && !spaceTabs(in: spaceID).contains { $0.isPinned } }

    private var draggedTabCanPin: Bool {
        guard let id = model.draggingTabID, let tab = model.state.tabs.first(where: { $0.id == id }) else { return false }
        return !tab.isPinned
    }

    /// Only shown mid-drag so a Space with no pinned tabs still has somewhere to drop one.
    private var pinDropHint: some View {
        HStack(spacing: ChocoSpace.u(6)) {
            DesignIcon("9fb54", size: 12).opacity(0.6)
            Text("ここにドロップして固定").font(ChocoTheme.font(11, weight: .semibold)).foregroundStyle(ChocoTheme.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(32))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(pinnedDropTargeted ? 0.6 : 0.34), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ここにドロップして固定")
        .accessibilityIdentifier("pin-drop-hint")
    }

    private func clearDivider(in spaceID: UUID) -> some View {
        HStack(spacing: ChocoSpace.u(6)) {
            Rectangle().fill(ChocoTheme.divider).frame(height: 1)
            Button { model.send(.clearToday) } label: {
                HStack(spacing: ChocoSpace.xxs) {
                    DesignIcon("d8aa1", size: 9)
                    Text("クリア").font(ChocoTheme.font(11, weight: .medium))
                }.foregroundStyle(ChocoTheme.secondary).opacity(clearHovered ? 1 : 0.75)
            }
            .buttonStyle(.plain).onHover { clearHovered = $0 }.disabled(!spaceTabs(in: spaceID).contains { !$0.isPinned })
            .help("Todayのタブをアーカイブへ移動").accessibilityIdentifier("clear-today")
        }.padding(.horizontal, ChocoSpace.xs).frame(height: ChocoSpace.u(16))
    }

    private var newTabButton: some View {
        Button { model.showCommand(.newTab) } label: {
            HStack(spacing: ChocoSpace.u(6)) {
                DesignIcon("77a3c", size: 11).opacity(0.75).frame(width: ChocoSpace.u(16), height: ChocoSpace.u(16))
                Text("新しいタブ").font(ChocoTheme.font(13, weight: .medium))
                Spacer(minLength: 0)
            }.padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(32)).contentShape(Rectangle())
        }.buttonStyle(ChocoPressStyle(radius: 8)).help("新しいタブ (⌘T)").accessibilityIdentifier("new-tab")
    }

    private func folderRow(_ folder: BrowserFolder, depth: Int) -> AnyView {
        let children = model.state.folders.filter { $0.parentID == folder.id }
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            Button {
                if !collapsedFolders.insert(folder.id).inserted { collapsedFolders.remove(folder.id) }
            } label: {
                HStack(spacing: ChocoSpace.sm) {
                    DesignIcon("9fb54", size: 12).opacity(0.6)
                        .rotationEffect(.degrees(collapsedFolders.contains(folder.id) ? 0 : 90))
                    Text(folder.name).font(ChocoTheme.font(13, weight: .medium)).foregroundStyle(ChocoTheme.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(32)).contentShape(Rectangle())
            }.buttonStyle(ChocoPressStyle(radius: 8)).accessibilityIdentifier("folder-\(folder.id)")
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
                .tabDrop(model: model) { id in
                    model.send(.moveTab(id, spaceID: folder.spaceID, folderID: folder.id)); return true
                }
            if !collapsedFolders.contains(folder.id) {
                VStack(spacing: 0) {
                    ForEach(children) { child in folderRow(child, depth: depth + 1) }
                    ForEach(presentedSpaceTabs(in: folder.spaceID).filter { $0.tab.folderID == folder.id }) { item in presentedTabRow(item) }
                }.padding(.leading, ChocoSpace.md)
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
            // Not a Button: a button owns the mouse-down, so a drag could never start from it.
            TabRowSurface(model: model, tab: tab, isSelected: isSelected(tab)) {
                HStack(spacing: ChocoSpace.u(6)) {
                    SiteIcon(url: tab.url, size: 16)
                    Text(tab.displayTitle).font(ChocoTheme.font(13, weight: .medium)).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.leading, ChocoSpace.u(10)).padding(.trailing, ChocoSpace.u(6)).frame(height: ChocoSpace.u(32))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tab.displayTitle)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.select(tab) }
            .accessibilityIdentifier("select-tab-\(tab.id)")
        }
        // The row being dragged stays behind as a faint ghost.
        .opacity(model.draggingTabID == tab.id ? 0.35 : 1)
        .animation(reduceMotion ? nil : ChocoMotion.tabLifecycle, value: model.draggingTabID == tab.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tab.displayTitle)
        .accessibilityIdentifier("tab-\(tab.id)")
        .contextMenu { tabMenu(tab) }
        .tabDrop(model: model) { id in
            guard let dragged = model.state.tabs.first(where: { $0.id == id }) else { return false }
            if tab.isPinned && !dragged.isPinned {
                // Pin it into the target's folder, then slot it in front of the target.
                model.send(.moveTab(id, spaceID: tab.spaceID, folderID: tab.folderID))
                model.send(.pinTab(id))
            }
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
        HStack(spacing: 0) {
            Button { model.showsArchive = true } label: {
                DesignIcon("e1841", size: 16).opacity(0.7).frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
            }.buttonStyle(ChocoPressStyle()).help("ライブラリ · アーカイブ").accessibilityLabel("ライブラリ").accessibilityIdentifier("open-archive")
            Spacer(minLength: 0)
            Button { model.showsNewMenu.toggle() } label: {
                // Figma "Plus Button (rotates to x)": a 45° turn while the New menu is open.
                DesignIcon("77a3c", size: 16).opacity(0.7)
                    .rotationEffect(.degrees(model.showsNewMenu ? 45 : 0))
                    .animation(reduceMotion ? nil : ChocoMotion.newMenuEntry, value: model.showsNewMenu)
                    .frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
            }
            .buttonStyle(ChocoPressStyle())
            .anchorPreference(key: NewMenuAnchorKey.self, value: .bounds) { $0 }
            .help("新規作成").accessibilityLabel("新規作成")
            .accessibilityValue(model.showsNewMenu ? "メニューを表示中" : "")
            .accessibilityIdentifier("new-menu")
        }
        // Figma "Space Dots" sits on the bar's own centre line, whatever the side buttons weigh.
        .overlay {
            ViewThatFits(in: .horizontal) {
                spaceDots
                ScrollView(.horizontal, showsIndicators: false) { spaceDots }
            }
            .padding(.horizontal, ChocoSpace.u(26) + ChocoSpace.u(4))
        }
        .frame(height: ChocoSpace.u(26))
    }

    /// Figma `Space Dots` (163:8024): every Space shows its icon (14pt, 8pt radius, 5% on hover) — full strength for the
    /// current one, 40% for the rest — and a 10×2pt `active indicator` under the current one slides to the new Space.
    private var spaceDots: some View {
        let selectedIndex = CGFloat(model.state.spaces.firstIndex { $0.id == model.state.selectedSpaceID } ?? 0)
        // While the fingers drag the lists the indicator travels with them.
        let activeIndex = slide.dragging && slide.outgoing != nil ? selectedIndex + slide.direction * slide.progress : selectedIndex
        return HStack(spacing: ChocoSpace.u(4)) {
            ForEach(model.state.spaces) { space in
                let isCurrent = model.state.selectedSpaceID == space.id
                Button { model.send(.selectSpace(space.id)) } label: {
                    SpaceIcon(space.icon, size: 14)
                        .opacity(isCurrent ? 1 : 0.4)
                        .animation(reduceMotion ? nil : ChocoMotion.spaceDotFade, value: isCurrent)
                        .frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
                }
                .buttonStyle(ChocoPressStyle(radius: 8)).help(space.name).accessibilityLabel("Space: \(space.name)")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityIdentifier("space-\(space.id)")
                .tabDrop(model: model) { id in
                    model.send(.moveTab(id, spaceID: space.id, folderID: nil)); return true
                }
            }
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.6))
                .frame(width: ChocoSpace.u(10), height: ChocoSpace.u(2))
                .offset(x: ChocoSpace.u(8) + activeIndex * (ChocoSpace.u(26) + ChocoSpace.u(4)), y: ChocoSpace.u(22))
                .animation(reduceMotion || slide.dragging ? nil : ChocoMotion.spaceIndicator, value: activeIndex)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

/// Where the sidebar's Space lists are in a Space switch: `current` is the list shown, `outgoing` the one leaving.
/// `direction` is 1 when the new Space comes after the old one (the lists move left), -1 otherwise.
private struct SpaceSlide {
    var current: UUID
    var outgoing: UUID?
    var direction: CGFloat = 1
    var progress: CGFloat = 1
    var outgoingOpacity: Double = 0
    var incomingOpacity: Double = 1
    /// Resistance offset when the fingers pull past the first or last Space.
    var rubber: CGFloat = 0
    /// The fingers are still down and the lists follow them.
    var dragging = false
}

/// A sidebar tab row: tints on hover, press and selection like `ChocoPressStyle`, selects on click, and lifts
/// off the sidebar when dragged (`TabDragSource` owns the mouse for all three).
private struct TabRowSurface<Content: View>: View {
    let model: AppModel
    let tab: BrowserTab
    let isSelected: Bool
    @ViewBuilder let content: Content
    @ChocoReducedMotion private var reduceMotion: Bool
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        content
            .padding(.trailing, hovering ? ChocoSpace.u(20) : 0)
            // Making room for the close button re-truncates the title; animating that cross-fades the two
            // truncations into a ghosted label, so the layout snaps and only the fills and the button fade.
            .animation(nil, value: hovering)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(ChocoTheme.selected).opacity(isSelected ? 1 : 0)
                    RoundedRectangle(cornerRadius: 8).fill(ChocoTheme.hover).opacity(hovering && !pressed && !isSelected ? 1 : 0)
                    RoundedRectangle(cornerRadius: 8).fill(ChocoTheme.selected).opacity(pressed ? 1 : 0)
                }.allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .overlay {
                TabDragSource(model: model, tab: tab, onPress: { pressed = $0 }, onClick: { model.select(tab) })
            }
            // Figma Tab Row: the close button shows only on hover; on the selected row it carries a 5% fill.
            .overlay(alignment: .trailing) {
                if hovering {
                    Button { model.send(.closeTab(tab.id)) } label: {
                        DesignIcon("98f70", size: 12).opacity(0.7).frame(width: ChocoSpace.u(20), height: ChocoSpace.u(20))
                            .background(isSelected && !pressed ? ChocoTheme.hover : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(ChocoPressStyle(radius: 5))
                    .padding(.trailing, ChocoSpace.u(6))
                    .help(tab.isPinned ? "固定タブを閉じる" : "タブをアーカイブ").accessibilityLabel("タブを閉じる")
                    .accessibilityIdentifier("close-tab-\(tab.id)")
                    // The title regains the button's room at once, so the button must not fade out over it.
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: pressed ? 0.07 : 0.23), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    /// Accepts the sidebar tab being dragged and moves it (so the pointer never shows a copy badge).
    fileprivate func tabDrop(model: AppModel, targeted: Binding<Bool>? = nil, perform: @escaping (UUID) -> Bool) -> some View {
        onDrop(of: [.plainText], delegate: TabMoveDropDelegate(model: model, targeted: targeted, perform: perform))
    }
}

private struct TabMoveDropDelegate: DropDelegate {
    let model: AppModel
    let targeted: Binding<Bool>?
    let perform: (UUID) -> Bool

    func validateDrop(info: DropInfo) -> Bool { model.draggingTabID != nil }
    func dropEntered(info: DropInfo) { targeted?.wrappedValue = true }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { targeted?.wrappedValue = false }
    func performDrop(info: DropInfo) -> Bool {
        targeted?.wrappedValue = false
        guard let id = model.draggingTabID else { return false }
        model.draggingTabID = nil
        return perform(id)
    }
}

enum FavoriteCell: Identifiable, Equatable {
    case favorite(BrowserFavorite), placeholder
    var id: String {
        switch self {
        case .favorite(let favorite): favorite.id.uuidString
        case .placeholder: "drop-placeholder"
        }
    }
}

/// Dropping a tab on Favorites moves it there. Over the tile grid a dashed slot follows the pointer
/// and the tiles make room for it; releasing puts the favorite in that slot.
private struct FavoriteDropDelegate: DropDelegate {
    static let tileWidth: CGFloat = ChocoSpace.u(56), columnGap: CGFloat = ChocoSpace.sm, rowGap: CGFloat = ChocoSpace.u(8), tileHeight: CGFloat = ChocoSpace.u(40)
    let model: AppModel
    let tracksSlot: Bool
    let animation: Animation?
    @Binding var targeted: Bool

    func validateDrop(info: DropInfo) -> Bool { model.draggedTabCanBecomeFavorite }

    func dropEntered(info: DropInfo) { targeted = true; model.dragOverFavorites = true; track(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? { track(info); return DropProposal(operation: .move) }

    func dropExited(info: DropInfo) {
        targeted = false
        model.dragOverFavorites = false
        withAnimation(animation) { model.favoriteDropIndex = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        targeted = false
        model.dragOverFavorites = false
        let index = model.favoriteDropIndex ?? model.state.favorites.count
        var accepted = false
        withAnimation(animation) { accepted = model.dropDraggedTabOnFavorites(at: index) }
        return accepted
    }

    private func track(_ info: DropInfo) {
        guard tracksSlot else { return }
        let column = min(2, max(0, Int(info.location.x / (Self.tileWidth + Self.columnGap))))
        let row = max(0, Int(info.location.y / (Self.tileHeight + Self.rowGap)))
        let index = min(model.state.favorites.count, row * 3 + column)
        if model.favoriteDropIndex != index { withAnimation(animation) { model.favoriteDropIndex = index } }
    }
}

/// The URL field's trailing 20pt tile (Figma `site controls`): lit while pressed and while its popover is open.
/// Figma `Favorite Tile`: 6% at rest, 7% on hover, 12% selected; pressing keeps 12% and shrinks the icon to 12pt at 92%.
private struct FavoriteTileStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        TileBody(configuration: configuration, isSelected: isSelected)
    }

    private struct TileBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.spaceTheme) private var theme
        @ChocoReducedMotion private var reduceMotion: Bool
        @State private var hovering = false

        var body: some View {
            let fill = configuration.isPressed || isSelected ? ChocoTheme.selected : hovering ? theme.field : ChocoTheme.tile
            configuration.label
                .scaleEffect(configuration.isPressed ? 12.0 / 14.0 : 1)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))
                .opacity(configuration.isPressed ? 0.92 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { hovering = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: configuration.isPressed ? 0.07 : 0.23), value: configuration.isPressed)
        }
    }
}

private struct SiteControlsButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        TileBody(configuration: configuration, isActive: isActive)
    }

    private struct TileBody: View {
        let configuration: Configuration
        let isActive: Bool
        @ChocoReducedMotion private var reduceMotion: Bool
        @State private var hovering = false

        var body: some View {
            let lit = configuration.isPressed || isActive
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(lit ? 0.2 : 0.12))
                        .frame(width: ChocoSpace.u(20), height: ChocoSpace.u(20))
                }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: lit ? 0.07 : 0.23), value: lit)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
        }
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
            .frame(height: (ChocoTheme.rowHeight + bottomGap) * phase, alignment: .top)
            .clipped()
            .opacity(Double(phase))
            .offset(x: -8 * (1 - phase))
    }
}
