import Foundation
import Observation

@MainActor @Observable public final class BrowserStore {
    public private(set) var state: BrowserState
    public private(set) var persistenceError: String?
    @ObservationIgnored private let writer: StateWriter
    @ObservationIgnored private let recoveryDiagnostic: String?
    @ObservationIgnored private var revision: UInt64 = 0

    public init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OssArc", isDirectory: true)
        let loaded = StatePersistence.load(directory: directory)
        state = loaded.state
        persistenceError = loaded.diagnostic
        recoveryDiagnostic = loaded.diagnostic
        writer = StateWriter(directory: directory, canSave: loaded.canSave)
    }

    public func send(_ action: BrowserAction) {
        let before = state
        switch action {
        case .newTab(let url):
            let tab = BrowserTab(spaceID: state.selectedSpaceID, url: nonempty(url, fallback: "about:blank"))
            state.tabs.append(tab); select(tab.id)
        case .newTabWithID(let id, let spaceID, let url):
            guard state.spaces.contains(where: { $0.id == spaceID }), !state.tabs.contains(where: { $0.id == id }) else { return }
            let tab = BrowserTab(id: id, spaceID: spaceID, url: nonempty(url, fallback: "about:blank"))
            state.tabs.append(tab); select(tab.id)
        case .selectTab(let id): select(id)
        case .selectFavorite(let id):
            guard state.favorites.contains(where: { $0.id == id }) else { return }
            state.selectedFavoriteID = id; state.selectedTabID = nil; state.split = nil
        case .closeTab(let id): close(id, explicitlyDelete: false)
        case .deleteTab(let id): close(id, explicitlyDelete: true)
        case .detachTab(let id): close(id, explicitlyDelete: true, archives: false)
        case .archiveTab(let tab):
            guard state.spaces.contains(where: { $0.id == tab.spaceID }), !state.tabs.contains(where: { $0.id == tab.id }) else { return }
            state.archive.insert(ArchiveEntry(tab: tab), at: 0)
        case .restoreLatestArchive:
            if let id = state.archive.first?.id { restore(id) }
        case .restoreArchive(let id): restore(id)
        case .renameTab(let id, let name):
            mutateTab(id) { $0.customTitle = trimmed(name).isEmpty ? nil : trimmed(name) }
        case .duplicateTab(let id):
            guard let index = state.tabs.firstIndex(where: { $0.id == id }) else { return }
            var copy = state.tabs[index]; copy.id = UUID()
            state.tabs.insert(copy, at: index + 1); select(copy.id)
        case .pinTab(let id): mutateTab(id) { if !$0.isPinned { $0.pinnedURL = $0.url } }
        case .unpinTab(let id): mutateTab(id) { $0.pinnedURL = nil; $0.folderID = nil }
        case .resetPinnedTab(let id): mutateTab(id) { if let pinned = $0.pinnedURL { $0.url = pinned } }
        case .setPinnedURL(let id, let url):
            guard !trimmed(url).isEmpty else { return }
            mutateTab(id) { if $0.isPinned { $0.pinnedURL = trimmed(url) } }
        case .moveTab(let id, let spaceID, let folderID):
            guard state.spaces.contains(where: { $0.id == spaceID }), let index = state.tabs.firstIndex(where: { $0.id == id }) else { return }
            if let folderID {
                guard state.folders.contains(where: { $0.id == folderID && $0.spaceID == spaceID }) else { return }
                if !state.tabs[index].isPinned { state.tabs[index].pinnedURL = state.tabs[index].url }
            }
            state.tabs[index].spaceID = spaceID; state.tabs[index].folderID = folderID
            collapseSplit(containing: id)
        case .moveTabBefore(let id, let beforeID):
            guard id != beforeID, let index = state.tabs.firstIndex(where: { $0.id == id }) else { return }
            let tab = state.tabs[index]
            if let beforeID {
                guard let target = state.tabs.first(where: { $0.id == beforeID }), target.spaceID == tab.spaceID,
                      target.folderID == tab.folderID, target.isPinned == tab.isPinned else { return }
            }
            state.tabs.remove(at: index)
            if let beforeID, let targetIndex = state.tabs.firstIndex(where: { $0.id == beforeID }) { state.tabs.insert(tab, at: targetIndex) }
            else if let last = state.tabs.lastIndex(where: { $0.spaceID == tab.spaceID && $0.folderID == tab.folderID && $0.isPinned == tab.isPinned }) { state.tabs.insert(tab, at: last + 1) }
            else { state.tabs.append(tab) }
        case .createFolder(let name, let parentID):
            guard !trimmed(name).isEmpty else { return }
            if let parentID { guard state.folders.contains(where: { $0.id == parentID && $0.spaceID == state.selectedSpaceID }) else { return } }
            state.folders.append(BrowserFolder(spaceID: state.selectedSpaceID, parentID: parentID, name: trimmed(name)))
        case .renameFolder(let id, let name):
            guard !trimmed(name).isEmpty, let index = state.folders.firstIndex(where: { $0.id == id }) else { return }
            state.folders[index].name = trimmed(name)
        case .moveFolder(let id, let parentID, let beforeID):
            guard id != parentID, id != beforeID,
                  let index = state.folders.firstIndex(where: { $0.id == id }) else { return }
            var folder = state.folders[index]
            if let parentID {
                guard state.folders.contains(where: { $0.id == parentID && $0.spaceID == folder.spaceID }) else { return }
                var ancestor: UUID? = parentID
                var visited: Set<UUID> = []
                while let candidate = ancestor {
                    guard candidate != id, visited.insert(candidate).inserted else { return }
                    ancestor = state.folders.first(where: { $0.id == candidate })?.parentID
                }
            }
            if let beforeID {
                guard state.folders.contains(where: { $0.id == beforeID && $0.spaceID == folder.spaceID && $0.parentID == parentID }) else { return }
            }
            folder.parentID = parentID
            state.folders.remove(at: index)
            if let beforeID, let destination = state.folders.firstIndex(where: { $0.id == beforeID }) {
                state.folders.insert(folder, at: destination)
            } else if let lastSibling = state.folders.lastIndex(where: { $0.spaceID == folder.spaceID && $0.parentID == parentID }) {
                state.folders.insert(folder, at: lastSibling + 1)
            } else { state.folders.append(folder) }
        case .deleteFolder(let id):
            guard let folder = state.folders.first(where: { $0.id == id }) else { return }
            for i in state.folders.indices where state.folders[i].parentID == id { state.folders[i].parentID = folder.parentID }
            for i in state.tabs.indices where state.tabs[i].folderID == id { state.tabs[i].folderID = folder.parentID }
            for i in state.archive.indices where state.archive[i].tab.folderID == id { state.archive[i].tab.folderID = folder.parentID }
            state.folders.removeAll { $0.id == id }
        case .createSpace(let name, let icon, let colorHex, let profileID):
            guard state.profiles.contains(where: { $0.id == profileID }), !trimmed(name).isEmpty else { return }
            let space = BrowserSpace(name: trimmed(name), icon: nonempty(icon, fallback: "🌐"), colorHex: normalizedColor(colorHex), profileID: profileID)
            state.spaces.append(space); switchSpace(space.id)
        case .updateSpace(let id, let name, let icon, let colorHex, let profileID):
            guard state.profiles.contains(where: { $0.id == profileID }), !trimmed(name).isEmpty,
                  let index = state.spaces.firstIndex(where: { $0.id == id }) else { return }
            state.spaces[index].name = trimmed(name); state.spaces[index].icon = nonempty(icon, fallback: "🌐")
            state.spaces[index].colorHex = normalizedColor(colorHex); state.spaces[index].profileID = profileID
        case .selectSpace(let id): switchSpace(id)
        case .createProfile(let name):
            guard !trimmed(name).isEmpty else { return }
            state.profiles.append(BrowserProfile(name: trimmed(name)))
        case .createFavorite(let title, let url):
            guard state.favorites.count < 12, !trimmed(url).isEmpty else { return }
            state.favorites.append(BrowserFavorite(title: nonempty(title, fallback: url), url: trimmed(url)))
        case .insertFavorite(let title, let url, let index):
            guard state.favorites.count < 12, !trimmed(url).isEmpty else { return }
            state.favorites.insert(BrowserFavorite(title: nonempty(title, fallback: url), url: trimmed(url)),
                                   at: min(max(0, index), state.favorites.count))
        case .updateFavorite(let id, let title, let url):
            guard !trimmed(url).isEmpty, let index = state.favorites.firstIndex(where: { $0.id == id }) else { return }
            state.favorites[index].title = nonempty(title, fallback: url); state.favorites[index].url = trimmed(url)
        case .deleteFavorite(let id): state.favorites.removeAll { $0.id == id }
        case .clearToday:
            let ids = state.tabs.filter { $0.spaceID == state.selectedSpaceID && !$0.isPinned }.map(\.id)
            for id in ids { close(id, explicitlyDelete: false) }
        case .setSplit(let leading, let trailing):
            guard leading != trailing,
                  let first = state.tabs.first(where: { $0.id == leading }),
                  let second = state.tabs.first(where: { $0.id == trailing }), first.spaceID == second.spaceID else { return }
            state.selectedSpaceID = first.spaceID; state.selectedFavoriteID = nil; state.selectedTabID = leading
            state.split = SplitState(leadingTabID: leading, trailingTabID: trailing)
        case .swapSplit:
            if let split = state.split { state.split = SplitState(leadingTabID: split.trailingTabID, trailingTabID: split.leadingTabID, fraction: 1 - split.fraction) }
        case .setSplitFraction(let fraction):
            guard fraction.isFinite else { return }; state.split?.fraction = min(0.8, max(0.2, fraction))
        case .clearSplit: state.split = nil
        case .toggleSidebar: state.sidebarVisible.toggle()
        }
        state.validateAndRepair()
        if state != before { scheduleSave() }
    }

    public func updatePage(tabID: UUID, url: String?, title: String?) {
        let before = state
        mutateTab(tabID) { tab in
            if let url, !trimmed(url).isEmpty { tab.url = url }
            if let title, !trimmed(title).isEmpty { tab.title = title }
        }
        if state != before { scheduleSave() }
    }

    public func flush() async { await persist(state, revision: revision) }

    private func select(_ id: UUID) {
        guard let tab = state.tabs.first(where: { $0.id == id }) else { return }
        state.selectedSpaceID = tab.spaceID; state.selectedTabID = id; state.selectedFavoriteID = nil
        if let split = state.split, split.leadingTabID != id && split.trailingTabID != id { state.split = nil }
    }

    private func switchSpace(_ id: UUID) {
        guard state.spaces.contains(where: { $0.id == id }) else { return }
        if state.selectedSpaceID != id { state.split = nil; state.selectedTabID = nil }
        state.selectedSpaceID = id
        if state.selectedFavoriteID == nil && !state.tabs.contains(where: { $0.id == state.selectedTabID && $0.spaceID == id }) {
            state.selectedTabID = state.tabs.first(where: { $0.spaceID == id })?.id
        }
    }

    private func mutateTab(_ id: UUID, _ mutation: (inout BrowserTab) -> Void) {
        guard let index = state.tabs.firstIndex(where: { $0.id == id }) else { return }; mutation(&state.tabs[index])
    }

    private func collapseSplit(containing id: UUID) {
        guard let split = state.split, split.leadingTabID == id || split.trailingTabID == id else { return }
        let other = split.leadingTabID == id ? split.trailingTabID : split.leadingTabID
        state.split = nil
        if state.selectedTabID == id { state.selectedTabID = other }
    }

    private func close(_ id: UUID, explicitlyDelete: Bool, archives: Bool = true) {
        guard let index = state.tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = state.tabs[index]
        collapseSplit(containing: id)
        if !tab.isPinned || explicitlyDelete {
            state.tabs.remove(at: index)
            if archives { state.archive.insert(ArchiveEntry(tab: tab), at: 0) }
        }
        if state.selectedTabID == id {
            state.selectedTabID = state.tabs.first(where: { $0.spaceID == state.selectedSpaceID && $0.id != id })?.id
        }
    }

    private func restore(_ id: UUID) {
        guard let index = state.archive.firstIndex(where: { $0.id == id }) else { return }
        var tab = state.archive.remove(at: index).tab
        if state.tabs.contains(where: { $0.id == tab.id }) { tab.id = UUID() }
        if !state.spaces.contains(where: { $0.id == tab.spaceID }) { tab.spaceID = state.selectedSpaceID; tab.folderID = nil }
        state.tabs.append(tab); select(tab.id)
    }

    private func scheduleSave() {
        revision &+= 1
        let snapshot = state, snapshotRevision = revision
        Task { await persist(snapshot, revision: snapshotRevision) }
    }

    private func persist(_ snapshot: BrowserState, revision snapshotRevision: UInt64) async {
        do {
            try await writer.write(snapshot, revision: snapshotRevision)
            if snapshotRevision == revision { persistenceError = recoveryDiagnostic }
        } catch {
            if snapshotRevision == revision { persistenceError = "変更を保存できませんでした。\(error.localizedDescription)" }
        }
    }
}
