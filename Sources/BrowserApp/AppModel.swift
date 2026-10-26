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
    var commandMode: CommandMode?
    var commandText = ""
    var commandError: String?
    var editor: EditorRequest?
    var showsArchive = false
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
        store.send(action)
        focusedPaneID = store.state.selectedTabID
        reconcile()
    }

    func showCommand(_ mode: CommandMode) {
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
        hibernatedTabIDs.remove(tab.id)
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
        hibernatedTabIDs.formIntersection(validTabs)
        hibernatedFavoriteSessionIDs.formIntersection(Set(favoriteSessions.values))
        let memoryIDs = Set(lastInteraction.keys).union(scrollAnchors.keys).union(activityFlags.keys)
        for id in memoryIDs where !validRuntimes.contains(id) { clearHibernationMemory(id) }
        rememberSelectedTab()
        scheduleHibernationIfOverCapacity()
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
        if let id = navigationTabID { send(.closeTab(id)) }
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
            hibernatedTabIDs.remove(id)
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

    private func clearHibernationMemory(_ id: UUID) {
        lastInteraction[id] = nil
        scrollAnchors[id] = nil
        activityFlags[id] = nil
        hibernatedTabIDs.remove(id)
        hibernatedFavoriteSessionIDs.remove(id)
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

enum CommandMode { case newTab, navigate }

enum EditorRequest: Identifiable {
    case tabName(UUID), pinnedURL(UUID), folder(UUID?), renameFolder(UUID), space(UUID?), profile, favorite(UUID?)
    var id: String { String(describing: self) }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x8D83C9
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}
