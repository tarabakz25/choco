import AppKit
import BrowserCore
import BrowserRuntime
import Observation
import SwiftUI
import WebKit

@MainActor @Observable final class AppModel {
    let store: BrowserStore
    let pool = WebSessionPool()
    var commandMode: CommandMode?
    var commandText = ""
    var commandError: String?
    var editor: EditorRequest?
    var showsArchive = false
    var showsSiteControls = false
    var showsNewMenu = false
    var showsFind = false
    var findText = ""
    var focusedPaneID: UUID?
    @ObservationIgnored weak var browserWindow: NSWindow?
    @ObservationIgnored private var favoriteSessions: [String: UUID] = [:]
    @ObservationIgnored private var knownURLs: [UUID: String] = [:]
    @ObservationIgnored private var mountedProfiles: [UUID: UUID] = [:]
    @ObservationIgnored private(set) var recentTabIDs: [UUID] = []
    @ObservationIgnored private var lastRememberedTabID: UUID?
    @ObservationIgnored private var tabCycleOrder: [UUID]?
    @ObservationIgnored private var tabCycleIndex = 0
    @ObservationIgnored private var tabCycleSpaceID: UUID?

    init(directory: URL? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        if let directory {
            store = BrowserStore(directory: directory)
        } else if let index = arguments.firstIndex(of: "--test-session"), arguments.indices.contains(index + 1),
           let sessionID = UUID(uuidString: arguments[index + 1]) {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OssArcUITests", isDirectory: true).appendingPathComponent(sessionID.uuidString, isDirectory: true)
            store = BrowserStore(directory: directory)
        } else if let index = arguments.firstIndex(of: "--data-directory"), arguments.indices.contains(index + 1) {
            store = BrowserStore(directory: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
        } else { store = BrowserStore() }
        if state.tabs.count == 1, let tab = state.tabs.first, tab.url == "about:blank", state.archive.isEmpty,
           let index = arguments.firstIndex(of: "--initial-url"), arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            store.updatePage(tabID: tab.id, url: url.absoluteString, title: nil)
        }
        rememberSelectedTab()
    }

    var state: BrowserState { store.state }
    var selectedSpace: BrowserSpace? { state.spaces.first { $0.id == state.selectedSpaceID } }
    var tint: Color { Color(hex: selectedSpace?.colorHex ?? "8D83C9") }
    var selectedTab: BrowserTab? { state.tabs.first { $0.id == state.selectedTabID } }
    /// Only pages currently mounted in the visible single or split layout may receive navigation.
    var visibleTabIDs: [UUID] {
        guard state.selectedFavoriteID == nil else { return [] }
        if let split = state.split {
            let ids = [split.leadingTabID, split.trailingTabID]
            return ids.filter { id in state.tabs.contains { $0.id == id && $0.spaceID == state.selectedSpaceID } }
        }
        if let tab = selectedTab, tab.spaceID == state.selectedSpaceID { return [tab.id] }
        return []
    }
    var navigationTabID: UUID? {
        let visible = visibleTabIDs
        if let id = focusedPaneID, visible.contains(id) { return id }
        if let id = state.selectedTabID, visible.contains(id) { return id }
        return visible.first
    }
    var activeSession: WebSession? {
        if let id = navigationTabID, let tab = state.tabs.first(where: { $0.id == id }) { return session(for: tab) }
        if let id = state.selectedFavoriteID, let favorite = state.favorites.first(where: { $0.id == id }) { return session(for: favorite) }
        return nil
    }

    func send(_ action: BrowserAction) {
        finishTabCycle()
        switch action {
        case .closeTab(let id):
            if state.tabs.first(where: { $0.id == id })?.isPinned == true { pool.remove(id: id); mountedProfiles[id] = nil; knownURLs[id] = nil }
        case .updateFavorite(let id, _, _):
            let matches = favoriteSessions.filter { $0.key.hasPrefix(id.uuidString + ":") }
            for (key, sessionID) in matches { pool.remove(id: sessionID); favoriteSessions[key] = nil; mountedProfiles[sessionID] = nil }
        default: break
        }
        store.send(action)
        focusedPaneID = store.state.selectedTabID
        reconcile()
    }

    func showCommand(_ mode: CommandMode) {
        showsSiteControls = false
        showsNewMenu = false
        commandMode = mode
        commandError = nil
        commandText = mode == .navigate ? (activeSession?.url?.absoluteString ?? selectedTab?.url ?? "") : ""
    }

    func open(_ text: String, newTab: Bool) {
        guard let url = AddressResolver.resolve(text) else { commandError = "検索語、またはHTTP・HTTPSのURLを入力してください。"; return }
        commandError = nil
        if newTab || activeSession == nil {
            send(.newTab(url: url.absoluteString))
        } else if let id = navigationTabID, let tab = state.tabs.first(where: { $0.id == id }) {
            session(for: tab).navigate(to: url)
            store.updatePage(tabID: id, url: url.absoluteString, title: nil)
        } else { activeSession?.navigate(to: url) }
        commandMode = nil
    }

    func session(for tab: BrowserTab) -> WebSession {
        guard let space = state.spaces.first(where: { $0.id == tab.spaceID }) else { preconditionFailure("A tab must belong to a Space") }
        let session = pool.session(id: tab.id, profileID: space.profileID, initialURL: URL(string: tab.url))
        mountedProfiles[tab.id] = space.profileID
        if knownURLs[tab.id] == nil { knownURLs[tab.id] = tab.url }
        configure(session, tabID: tab.id, spaceID: tab.spaceID)
        return session
    }

    func session(for favorite: BrowserFavorite) -> WebSession {
        let profile = selectedSpace?.profileID ?? state.profiles[0].id
        let key = "\(favorite.id):\(profile)"
        let id: UUID
        if let cached = favoriteSessions[key] { id = cached } else { id = UUID(); favoriteSessions[key] = id }
        let session = pool.session(id: id, profileID: profile, initialURL: URL(string: favorite.url))
        mountedProfiles[id] = profile
        configure(session, tabID: nil, spaceID: state.selectedSpaceID)
        return session
    }

    private func configure(_ session: WebSession, tabID: UUID?, spaceID: UUID) {
        session.onPageChange = { [weak self] url, title in
            guard let self, let tabID else { return }
            self.knownURLs[tabID] = url?.absoluteString ?? self.knownURLs[tabID]
            self.store.updatePage(tabID: tabID, url: url?.absoluteString, title: title.isEmpty ? nil : title)
        }
        let originatingProfileID = session.profileID
        session.onOpenWindow = { [weak self] configuration, url in
            guard let self else { return nil }
            let currentSpaceID: UUID
            if let tabID {
                guard let tab = self.state.tabs.first(where: { $0.id == tabID }) else { return nil }
                currentSpaceID = tab.spaceID
            } else { currentSpaceID = spaceID }
            guard let origin = self.state.spaces.first(where: { $0.id == currentSpaceID }),
                  origin.profileID == originatingProfileID,
                  configuration.websiteDataStore.identifier == originatingProfileID else { return nil }
            let id = UUID()
            guard let popup = self.pool.adopt(id: id, profileID: originatingProfileID, configuration: configuration) else { return nil }
            self.store.send(.newTabWithID(id: id, spaceID: currentSpaceID, url: url?.absoluteString ?? "about:blank"))
            self.mountedProfiles[id] = origin.profileID
            self.knownURLs[id] = url?.absoluteString ?? "about:blank"
            self.configure(popup, tabID: id, spaceID: currentSpaceID)
            self.focusTab(id)
            return popup.webView
        }
        session.onClose = { [weak self] in
            guard let self, let tabID else { return }
            self.send(.closeTab(tabID))
        }
    }

    func reconcile() {
        let validTabs = Set(state.tabs.map(\.id))
        let validFavorites = Set(state.favorites.map { $0.id.uuidString })
        let validProfiles = Set(state.profiles.map { $0.id.uuidString })
        favoriteSessions = favoriteSessions.filter { key, _ in
            let parts = key.split(separator: ":").map(String.init)
            return parts.count == 2 && validFavorites.contains(parts[0]) && validProfiles.contains(parts[1])
        }
        let retained = validTabs.union(favoriteSessions.values)
        pool.retainOnly(retained)
        for (id, profile) in mountedProfiles {
            guard retained.contains(id) else { mountedProfiles[id] = nil; knownURLs[id] = nil; continue }
            if let tab = state.tabs.first(where: { $0.id == id }),
               let space = state.spaces.first(where: { $0.id == tab.spaceID }) {
                if profile != space.profileID { pool.remove(id: id); mountedProfiles[id] = nil; knownURLs[id] = nil }
                else if let previous = knownURLs[id], previous != tab.url {
                    let session = pool.session(id: id, profileID: profile)
                    if let url = URL(string: tab.url), session.url?.absoluteString != tab.url { session.navigate(to: url) }
                    knownURLs[id] = tab.url
                }
            }
        }
        if let focusedPaneID, !visibleTabIDs.contains(focusedPaneID) { self.focusedPaneID = navigationTabID }
        recentTabIDs.removeAll { !validTabs.contains($0) }
        rememberSelectedTab()
    }

    /// Selecting a split pane must also update persisted selection without collapsing the split.
    func focusTab(_ id: UUID?) {
        guard let id, visibleTabIDs.contains(id) else { return }
        finishTabCycle()
        if state.selectedTabID != id { store.send(.selectTab(id)) }
        focusedPaneID = id
        rememberSelectedTab()
    }

    private func rememberSelectedTab() {
        guard tabCycleOrder == nil, let id = state.selectedTabID,
              state.tabs.contains(where: { $0.id == id }), id != lastRememberedTabID else { return }
        recentTabIDs.removeAll { $0 == id }
        recentTabIDs.insert(id, at: 0)
        lastRememberedTabID = id
    }

    func select(_ tab: BrowserTab) {
        if tab.spaceID != state.selectedSpaceID { send(.selectSpace(tab.spaceID)) }
        send(.selectTab(tab.id))
        commandMode = nil
    }

    /// Freeze MRU order during a Control-Tab gesture; releasing Control commits only the final tab.
    func cycleTabs(backwards: Bool) {
        let tabs = state.tabs.filter { $0.spaceID == state.selectedSpaceID }
        guard !tabs.isEmpty else { return }
        if tabCycleOrder == nil || tabCycleSpaceID != state.selectedSpaceID {
            finishTabCycle()
            let currentID = navigationTabID
            var order: [UUID] = []
            for id in [currentID].compactMap({ $0 }) + recentTabIDs + tabs.map(\.id) {
                if tabs.contains(where: { $0.id == id }) && !order.contains(id) { order.append(id) }
            }
            tabCycleOrder = order
            tabCycleSpaceID = state.selectedSpaceID
            tabCycleIndex = currentID == nil ? (backwards ? 0 : -1) : 0
        }
        guard let order = tabCycleOrder, !order.isEmpty else { return }
        tabCycleIndex = (tabCycleIndex + (backwards ? order.count - 1 : 1)) % order.count
        let id = order[tabCycleIndex]
        store.send(.selectTab(id))
        focusedPaneID = id
        commandMode = nil
        reconcile()
    }

    func finishTabCycle() {
        guard tabCycleOrder != nil else { return }
        tabCycleOrder = nil
        tabCycleSpaceID = nil
        tabCycleIndex = 0
        rememberSelectedTab()
    }

    func cycleSpaces(backwards: Bool) {
        guard let index = state.spaces.firstIndex(where: { $0.id == state.selectedSpaceID }) else { return }
        send(.selectSpace(state.spaces[(index + (backwards ? state.spaces.count - 1 : 1)) % state.spaces.count].id))
    }

    func closeActive() {
        if commandMode != nil { commandMode = nil; return }
        if showsNewMenu { showsNewMenu = false; return }
        if showsSiteControls { showsSiteControls = false; return }
        if showsArchive { showsArchive = false; return }
        if let id = navigationTabID { send(.closeTab(id)) }
    }

    /// Opens a blank tab beside the current one and asks for its address.
    func newSplit() {
        showsNewMenu = false
        guard state.split == nil, let current = selectedTab else { return }
        send(.newTab(url: "about:blank"))
        if let created = selectedTab, created.id != current.id {
            send(.setSplit(leading: current.id, trailing: created.id))
        }
        showCommand(.navigate)
    }

    func split(with tab: BrowserTab) {
        guard let current = selectedTab, current.id != tab.id, current.spaceID == tab.spaceID else { return }
        send(.setSplit(leading: current.id, trailing: tab.id))
    }
}
