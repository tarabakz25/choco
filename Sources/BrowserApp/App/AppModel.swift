import BrowserLocalization
import AppKit
import BrowserCore
import BrowserRuntime
import Observation
import SwiftUI
import WebKit

@MainActor @Observable final class AppModel {
    let store: BrowserStore
    let pool = WebSessionPool()
    let extensions: ExtensionManager
    let extensionHost: ExtensionHost
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
    /// The sidebar tab currently being dragged; drop zones appear while it is set.
    var draggingTabID: UUID?
    /// Slot a dragged tab would take in the Favorites grid while it hovers there.
    var favoriteDropIndex: Int?
    /// The pointer is over the Favorites area with a droppable tab; the drag image shrinks to a tile.
    var dragOverFavorites = false
    /// While the window colour is between two Spaces: a swipe sets `progress` with the fingers, a plain switch animates it.
    private(set) var spaceBlend: SpaceBlend?
    /// Mirrors the in-app motion preference (set by the window); a Space switch then changes the colour at once.
    var reducesMotion = false
    @ObservationIgnored private var spaceBlendTask: Task<Void, Never>?
    @ObservationIgnored weak var browserWindow: NSWindow?
    @ObservationIgnored private var favoriteSessions: [String: UUID] = [:]
    @ObservationIgnored private var knownURLs: [UUID: String] = [:]
    @ObservationIgnored private var mountedProfiles: [UUID: UUID] = [:]
    @ObservationIgnored private(set) var recentTabIDs: [UUID] = []
    @ObservationIgnored private var lastRememberedTabID: UUID?
    @ObservationIgnored private var tabCycleOrder: [UUID]?
    @ObservationIgnored private var tabCycleIndex = 0
    @ObservationIgnored private var tabCycleSpaceID: UUID?
    @ObservationIgnored private var detachedWindows: [UUID: DetachedTabWindow] = [:]
    /// Tabs whose web view was discarded. The sidebar does not draw this yet.
    private(set) var hibernatedTabIDs: Set<UUID> = []
    @ObservationIgnored private(set) var hibernatedFavoriteSessionIDs: Set<UUID> = []
    @ObservationIgnored private var lastInteraction: [UUID: Date] = [:]
    @ObservationIgnored private var previouslyVisibleIDs: Set<UUID> = []
    @ObservationIgnored private(set) var scrollAnchors: [UUID: ScrollAnchor] = [:]
    @ObservationIgnored private var activityFlags: [UUID: TabActivityFlags] = [:]
    @ObservationIgnored private let memoryWatch = MemoryWatchBag()

    init(directory: URL? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let storeDirectory: URL
        if let directory {
            storeDirectory = directory
        } else if let index = arguments.firstIndex(of: "--test-session"), arguments.indices.contains(index + 1),
           let sessionID = UUID(uuidString: arguments[index + 1]) {
            storeDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OssArcUITests", isDirectory: true).appendingPathComponent(sessionID.uuidString, isDirectory: true)
        } else if let index = arguments.firstIndex(of: "--data-directory"), arguments.indices.contains(index + 1) {
            storeDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else { storeDirectory = BrowserStore.defaultDirectory }
        store = BrowserStore(directory: storeDirectory)
        extensions = ExtensionManager(directory: storeDirectory.appendingPathComponent("Extensions", isDirectory: true))
        extensionHost = ExtensionHost(manager: extensions)
        extensionHost.model = self
        extensions.delegate = extensionHost
        pool.extensions = extensions
        pool.onSessionAdded = { [extensionHost] session in extensionHost.sessionAdded(session) }
        pool.onSessionRemoved = { [extensionHost] session in extensionHost.sessionRemoved(session) }
        if state.tabs.count == 1, let tab = state.tabs.first, tab.url == "about:blank", state.archive.isEmpty,
           let index = arguments.firstIndex(of: "--initial-url"), arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            store.updatePage(tabID: tab.id, url: url.absoluteString, title: nil)
        }
        rememberSelectedTab()
        touchVisibleTabs()
        startMemoryWatch()
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
            if state.tabs.first(where: { $0.id == id })?.isPinned == true {
                pool.remove(id: id)
                mountedProfiles[id] = nil
                knownURLs[id] = nil
                clearHibernationMemory(id)
            }
        case .updateFavorite(let id, _, _):
            let matches = favoriteSessions.filter { $0.key.hasPrefix(id.uuidString + ":") }
            for (key, sessionID) in matches {
                pool.remove(id: sessionID)
                favoriteSessions[key] = nil
                mountedProfiles[sessionID] = nil
                clearHibernationMemory(sessionID)
            }
        default: break
        }
        let previousSpaceID = store.state.selectedSpaceID
        store.send(action)
        followSpaceChange(from: previousSpaceID, to: store.state.selectedSpaceID)
        focusedPaneID = store.state.selectedTabID
        reconcile()
    }

    struct SpaceBlend: Equatable {
        var from: UUID
        var to: UUID
        var progress: Double
    }

    /// Palette of a Space, or of the selected one when the id is unknown.
    func spaceTheme(for id: UUID) -> SpaceTheme {
        SpaceTheme(colorHex: state.spaces.first { $0.id == id }?.colorHex ?? selectedSpace?.colorHex)
    }

    /// The palette the window shows right now: the selected Space's, or the mix while a switch is under way.
    var currentSpaceTheme: SpaceTheme {
        guard let blend = spaceBlend else { return spaceTheme(for: state.selectedSpaceID) }
        return spaceTheme(for: blend.from).mixed(with: spaceTheme(for: blend.to), t: blend.progress)
    }

    /// A finger-driven blend: `progress` follows the swipe with no animation.
    func dragSpaceBlend(from: UUID, to: UUID, progress: Double) {
        spaceBlendTask?.cancel()
        spaceBlend = SpaceBlend(from: from, to: to, progress: progress)
    }

    /// Drops any blend (the swipe is resisting at the first or last Space).
    func clearSpaceBlend() {
        spaceBlendTask?.cancel()
        spaceBlend = nil
    }

    /// Carries a blend on from where it is to `progress` (1 finishes the switch, 0 settles back) on the Space spring.
    func settleSpaceBlend(to progress: Double) {
        spaceBlendTask?.cancel()
        guard spaceBlend != nil else { return }
        guard !reducesMotion else { spaceBlend = nil; return }
        spaceBlendTask = Task { @MainActor [weak self] in
            // Let the last frame of the swipe land first, so a quick flick still has a colour to ease away from.
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
            withAnimation(ChocoMotion.space) { self?.spaceBlend?.progress = progress }
            do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
            self?.spaceBlend = nil
        }
    }

    /// Whatever changed the selected Space (a dot, a shortcut, the command bar, a tab in another Space), the window
    /// colour eases across from the old Space's palette. A swipe has already started this blend itself.
    private func followSpaceChange(from old: UUID, to new: UUID) {
        guard old != new else { return }
        if let blend = spaceBlend, blend.from == old, blend.to == new { return }
        spaceBlendTask?.cancel()
        guard !reducesMotion else { spaceBlend = nil; return }
        spaceBlend = SpaceBlend(from: old, to: new, progress: 0)
        spaceBlendTask = Task { @MainActor [weak self] in
            // One frame at the old colour, so the change has a start to animate from.
            do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            withAnimation(ChocoMotion.space) { self?.spaceBlend?.progress = 1 }
            do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
            self?.spaceBlend = nil
        }
    }

    /// The page that browser shortcuts act on: a detached window's own page while it is key, else the active tab.
    var keySession: WebSession? {
        if let window = NSApp.keyWindow, let detached = detachedWindows.values.first(where: { $0.window === window }) { return detached.session }
        return activeSession
    }

    /// The Space extensions should open new tabs in: the selected one when it uses this profile, else any that does.
    func space(preferring profileID: UUID) -> BrowserSpace? {
        if let selected = selectedSpace, selected.profileID == profileID { return selected }
        return state.spaces.first { $0.profileID == profileID }
    }

    func showMainWindow() { browserWindow?.makeKeyAndOrderFront(nil) }

    func showCommand(_ mode: CommandMode) {
        showMainWindow()
        showsSiteControls = false
        showsNewMenu = false
        commandMode = mode
        commandError = nil
        commandText = mode == .navigate ? (activeSession?.url?.absoluteString ?? selectedTab?.url ?? "") : ""
    }

    func open(_ text: String, newTab: Bool) {
        guard let url = AddressResolver.resolve(text) else { commandError = "Enter a search term or an HTTP or HTTPS URL."; return }
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
        let restoring = pool.existing(id: tab.id) == nil ? pageScroll(for: tab.id) : nil
        wakeFromHibernation(tab.id)
        let session = pool.session(id: tab.id, profileID: space.profileID, initialURL: URL(string: tab.url), restoreScroll: restoring)
        mountedProfiles[tab.id] = space.profileID
        if knownURLs[tab.id] == nil { knownURLs[tab.id] = tab.url }
        configure(session, tabID: tab.id, spaceID: tab.spaceID)
        noteInteraction(tab.id, at: Date())
        return session
    }

    func session(for favorite: BrowserFavorite) -> WebSession {
        let profile = selectedSpace?.profileID ?? state.profiles[0].id
        let id = favoriteRuntimeID(for: favorite)
        let restoring = pool.existing(id: id) == nil ? pageScroll(for: id) : nil
        hibernatedFavoriteSessionIDs.remove(id)
        let session = pool.session(id: id, profileID: profile, initialURL: URL(string: favorite.url), restoreScroll: restoring)
        mountedProfiles[id] = profile
        configure(session, tabID: nil, spaceID: state.selectedSpaceID)
        noteInteraction(id, at: Date())
        return session
    }

    func favoriteRuntimeID(for favorite: BrowserFavorite) -> UUID {
        let profile = selectedSpace?.profileID ?? state.profiles[0].id
        let key = "\(favorite.id):\(profile)"
        if let cached = favoriteSessions[key] { return cached }
        let id = UUID()
        favoriteSessions[key] = id
        return id
    }

    private func configure(_ session: WebSession, tabID: UUID?, spaceID: UUID) {
        session.onPageChange = { [weak self] url, title in
            guard let self, let tabID else { return }
            let absolute = url?.absoluteString
            if let absolute, self.knownURLs[tabID] != absolute { self.scrollAnchors[tabID] = nil }
            self.knownURLs[tabID] = absolute ?? self.knownURLs[tabID]
            self.store.updatePage(tabID: tabID, url: absolute, title: title.isEmpty ? nil : title)
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
        touchVisibleTabs()
        let validTabs = Set(state.tabs.map(\.id))
        let validFavorites = Set(state.favorites.map { $0.id.uuidString })
        let validProfiles = Set(state.profiles.map { $0.id.uuidString })
        favoriteSessions = favoriteSessions.filter { key, _ in
            let parts = key.split(separator: ":").map(String.init)
            return parts.count == 2 && validFavorites.contains(parts[0]) && validProfiles.contains(parts[1])
        }
        let retained = validTabs.subtracting(hibernatedTabIDs).union(Set(favoriteSessions.values).subtracting(hibernatedFavoriteSessionIDs))
        pool.retainOnly(retained)
        for (id, profile) in mountedProfiles {
            guard retained.contains(id) else { mountedProfiles[id] = nil; knownURLs[id] = nil; continue }
            if let tab = state.tabs.first(where: { $0.id == id }),
               let space = state.spaces.first(where: { $0.id == tab.spaceID }) {
                if profile != space.profileID {
                    pool.remove(id: id)
                    mountedProfiles[id] = nil
                    knownURLs[id] = nil
                    clearHibernationMemory(id)
                }
                else if let previous = knownURLs[id], previous != tab.url {
                    scrollAnchors[id] = nil
                    let session = pool.session(id: id, profileID: profile)
                    if let url = URL(string: tab.url), session.url?.absoluteString != tab.url { session.navigate(to: url) }
                    knownURLs[id] = tab.url
                }
            }
        }
        if let focusedPaneID, !visibleTabIDs.contains(focusedPaneID) { self.focusedPaneID = navigationTabID }
        recentTabIDs.removeAll { !validTabs.contains($0) }
        let validRuntimes = validTabs.union(favoriteSessions.values)
        if !hibernatedTabIDs.isSubset(of: validTabs) { hibernatedTabIDs.formIntersection(validTabs) }
        hibernatedFavoriteSessionIDs.formIntersection(Set(favoriteSessions.values))
        let memoryIDs = Set(lastInteraction.keys).union(scrollAnchors.keys).union(activityFlags.keys)
        for id in memoryIDs where !validRuntimes.contains(id) { clearHibernationMemory(id) }
        rememberSelectedTab()
        extensionHost.activeTabMayHaveChanged(to: navigationTabID.flatMap { pool.existing(id: $0) })
        scheduleHibernationIfOverCapacity()
    }

    /// Selecting a split pane must also update persisted selection without collapsing the split.
    func focusTab(_ id: UUID?) {
        guard let id, visibleTabIDs.contains(id) else { return }
        finishTabCycle()
        if state.selectedTabID != id { store.send(.selectTab(id)) }
        focusedPaneID = id
        rememberSelectedTab()
        extensionHost.activeTabMayHaveChanged(to: pool.existing(id: id))
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

    /// Builds the planner input from current tabs, favorite sessions, and cached activity flags.
    /// `liveIDs` overrides pool membership so tests can describe resident pages without creating web views.
    func memorySnapshots(now: Date, liveIDs: Set<UUID>? = nil, touchVisible: Bool = true) -> [TabMemorySnapshot] {
        if touchVisible { touchVisibleTabs(at: now) }
        var snapshots: [TabMemorySnapshot] = []
        var emitted: Set<UUID> = []
        for tab in state.tabs {
            snapshots.append(memorySnapshot(id: tab.id, visible: visibleTabIDs.contains(tab.id), pinned: tab.isPinned, liveIDs: liveIDs))
            emitted.insert(tab.id)
        }
        for id in favoriteSessions.values where !emitted.contains(id) {
            snapshots.append(memorySnapshot(id: id, visible: id == selectedFavoriteRuntimeID, pinned: false, liveIDs: liveIDs))
        }
        return snapshots
    }

    func applyHibernationPlan(_ plan: HibernationPlan) {
        let visible = Set(visibleTabIDs)
        let pinned = Set(state.tabs.filter(\.isPinned).map(\.id))
        let selectedFavorite = selectedFavoriteRuntimeID
        let wake = Set(plan.wakeIDs)
        for id in plan.hibernateIDs where !wake.contains(id) {
            if visible.contains(id) || pinned.contains(id) || id == selectedFavorite { continue }
            if activityFlags[id]?.isPlayingAudio == true || activityFlags[id]?.hasUnsavedFormInput == true { continue }
            if (pool.existing(id: id)?.activeDownloadCount ?? 0) > 0 { continue }
            pool.remove(id: id)
            mountedProfiles[id] = nil
            if state.tabs.contains(where: { $0.id == id }) { hibernatedTabIDs.insert(id) }
            else { hibernatedFavoriteSessionIDs.insert(id) }
        }
        for id in plan.wakeIDs {
            wakeFromHibernation(id)
            hibernatedFavoriteSessionIDs.remove(id)
        }
        scrollAnchors = ScrollAnchorBudget.trimmed(scrollAnchors, maxCount: ScrollAnchorBudget.defaultMaxCount)
    }

    func applyMemoryPolicy(now: Date = Date(), pressure: MemoryPressureLevel = .normal) async {
        touchVisibleTabs(at: now)
        await refreshHibernationCandidates(now: now)
        let snapshots = memorySnapshots(now: now, touchVisible: false)
        let plan = TabHibernationPlanner.plan(tabs: snapshots, now: now, budget: .standard, pressure: pressure)
        applyHibernationPlan(plan)
    }

    func noteInteraction(_ id: UUID, at date: Date) {
        lastInteraction[id] = date
    }

    func noteActivity(_ id: UUID, isPlayingAudio: Bool, hasUnsavedFormInput: Bool) {
        activityFlags[id] = TabActivityFlags(isPlayingAudio: isPlayingAudio, hasUnsavedFormInput: hasUnsavedFormInput)
    }

    func noteScroll(_ id: UUID, x: Double, y: Double, at date: Date) {
        scrollAnchors[id] = ScrollAnchor(x: x, y: y, savedAt: date)
    }

    private var selectedFavoriteRuntimeID: UUID? {
        guard let favoriteID = state.selectedFavoriteID, let profileID = selectedSpace?.profileID else { return nil }
        return favoriteSessions["\(favoriteID):\(profileID)"]
    }

    private func memorySnapshot(id: UUID, visible: Bool, pinned: Bool, liveIDs: Set<UUID>?) -> TabMemorySnapshot {
        let flags = activityFlags[id]
        let session = pool.existing(id: id)
        return TabMemorySnapshot(
            id: id,
            lastInteraction: lastInteraction[id] ?? .distantPast,
            isVisible: visible,
            isPinned: pinned,
            isPlayingAudio: flags?.isPlayingAudio ?? false,
            isDownloading: (session?.activeDownloadCount ?? 0) > 0,
            hasUnsavedFormInput: flags?.hasUnsavedFormInput ?? false,
            isLive: liveIDs?.contains(id) ?? (session != nil)
        )
    }

    private func touchVisibleTabs(at date: Date = Date()) {
        var visible = Set(visibleTabIDs)
        if let favorite = selectedFavoriteRuntimeID { visible.insert(favorite) }
        for id in visible.union(previouslyVisibleIDs) { lastInteraction[id] = date }
        previouslyVisibleIDs = visible
    }

    private func refreshHibernationCandidates(now: Date) async {
        let visible = Set(visibleTabIDs)
        let pinned = Set(state.tabs.filter(\.isPinned).map(\.id))
        let selectedFavorite = selectedFavoriteRuntimeID
        for id in pool.residentIDs {
            if Task.isCancelled { return }
            if visible.contains(id) || pinned.contains(id) || id == selectedFavorite { continue }
            guard let session = pool.existing(id: id) else { continue }
            guard let probe = await session.capturePageMemory() else { continue }
            noteActivity(id, isPlayingAudio: probe.isPlayingAudio, hasUnsavedFormInput: probe.hasUnsavedFormInput)
            noteScroll(id, x: probe.scrollX, y: probe.scrollY, at: now)
        }
    }

    private func scheduleHibernationIfOverCapacity() {
        guard pool.residentIDs.count > HibernationBudget.standard.maxLiveWebViews else { return }
        memoryWatch.pass?.cancel()
        memoryWatch.pass = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            await self.applyMemoryPolicy(pressure: .normal)
        }
    }

    private func startMemoryWatch() {
        memoryWatch.loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                await self.applyMemoryPolicy(pressure: .normal)
            }
        }
        memoryWatch.pressure = MemoryPressureWatch { [weak self] pressure in
            Task { @MainActor in
                await self?.applyMemoryPolicy(pressure: pressure)
            }
        }
    }

    private func pageScroll(for id: UUID) -> PageScrollOffset? {
        guard let anchor = scrollAnchors[id] else { return nil }
        return PageScrollOffset(x: anchor.x, y: anchor.y)
    }

    /// `session(for:)` runs while the sidebar draws, so a write to this observed set must only happen when it
    /// changes: even a no-op `remove` counts as a mutation, which invalidates the view and loops the draw.
    private func wakeFromHibernation(_ id: UUID) {
        if hibernatedTabIDs.contains(id) { hibernatedTabIDs.remove(id) }
    }

    private func clearHibernationMemory(_ id: UUID) {
        lastInteraction[id] = nil
        scrollAnchors[id] = nil
        activityFlags[id] = nil
        wakeFromHibernation(id)
        hibernatedFavoriteSessionIDs.remove(id)
    }

    // MARK: Dragging a tab out of the sidebar

    func beginTabDrag(_ id: UUID) { draggingTabID = id }

    /// Called when the AppKit drag session ends. A drop target that accepted the tab has already cleared
    /// `draggingTabID`; a tab still being dragged that was released over no window of ours opens its own window.
    func endTabDrag(operation: NSDragOperation, cancelled: Bool, at point: NSPoint) {
        let id = draggingTabID
        draggingTabID = nil
        favoriteDropIndex = nil
        dragOverFavorites = false
        guard let id, operation.isEmpty, !cancelled, state.tabs.contains(where: { $0.id == id }) else { return }
        // Drag-image windows can't become main, so only real windows count as "inside".
        guard !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain && $0.frame.contains(point) }) else { return }
        detach(id, near: point)
    }

    /// Whether the dragged tab could become a favorite: a real page that isn't one already, with room left.
    var draggedTabCanBecomeFavorite: Bool {
        guard let id = draggingTabID, let tab = state.tabs.first(where: { $0.id == id }), tab.url != "about:blank" else { return false }
        return state.favorites.count < 12 && !state.favorites.contains { $0.url == tab.url }
    }

    /// Moves the dragged tab into Favorites at `index`; the tab leaves the list, and stays on screen if it was the open page.
    func dropDraggedTabOnFavorites(at index: Int) -> Bool {
        guard draggedTabCanBecomeFavorite, let id = draggingTabID, let tab = state.tabs.first(where: { $0.id == id }) else { return false }
        draggingTabID = nil
        favoriteDropIndex = nil
        dragOverFavorites = false
        let wasOpen = state.selectedTabID == id
        send(.insertFavorite(title: tab.displayTitle, url: tab.url, at: index))
        let slot = min(max(0, index), state.favorites.count - 1)
        send(.detachTab(id))
        if wasOpen, state.favorites.indices.contains(slot) { send(.selectFavorite(state.favorites[slot].id)) }
        return true
    }

    func detach(_ id: UUID, near point: NSPoint) {
        guard let tab = state.tabs.first(where: { $0.id == id }) else { return }
        let live = session(for: tab)
        guard pool.release(id: id) === live else { return }
        send(.detachTab(id))
        // Popups opened from the detached page join the main window in the tab's Space.
        configure(live, tabID: nil, spaceID: tab.spaceID)
        let window = DetachedTabWindow(model: self, tab: tab, session: live)
        live.onClose = { [weak window] in window?.finish() }
        detachedWindows[id] = window
        window.show(near: point)
    }

    func releaseDetached(_ id: UUID) { detachedWindows[id] = nil }

    /// Closes every detached window, archiving its tab, so quitting never loses an open page.
    func closeDetachedWindows() {
        for window in Array(detachedWindows.values) { window.finish() }
    }
}

private struct TabActivityFlags: Equatable {
    var isPlayingAudio: Bool
    var hasUnsavedFormInput: Bool
}

/// Cancels the idle loop when the model is released so tests are not left sleeping.
private final class MemoryWatchBag: @unchecked Sendable {
    var loop: Task<Void, Never>?
    var pass: Task<Void, Never>?
    var pressure: MemoryPressureWatch?
    deinit {
        loop?.cancel()
        pass?.cancel()
        pressure = nil
    }
}

/// Dispatch memory warnings are delivered on the main queue. Cancel releases the source.
private final class MemoryPressureWatch: @unchecked Sendable {
    private var source: DispatchSourceMemoryPressure?

    init(onPressure: @escaping @Sendable (MemoryPressureLevel) -> Void) {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        self.source = source
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            let pressure: MemoryPressureLevel = source.data.contains(.critical) ? .critical : .warning
            onPressure(pressure)
        }
        source.resume()
    }

    deinit {
        source?.cancel()
        source = nil
    }
}
