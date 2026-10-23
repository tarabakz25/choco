import Foundation

extension BrowserState {
    /// Repairs structural references without silently discarding usable tabs.
    /// Schema compatibility is checked by the persistence loader before this runs.
    @discardableResult
    public mutating func validateAndRepair() -> [String] {
        let original = self
        profiles = unique(profiles)
        spaces = unique(spaces)
        // WebKit reserves the all-zero identifier and raises an Objective-C
        // exception rather than a Swift error when asked for that data store.
        let zeroID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        if profiles.contains(where: { $0.id == zeroID }) || spaces.contains(where: { $0.profileID == zeroID }) {
            var replacement = UUID()
            while profiles.contains(where: { $0.id == replacement }) { replacement = UUID() }
            if let index = profiles.firstIndex(where: { $0.id == zeroID }) { profiles[index].id = replacement }
            else { profiles.append(BrowserProfile(id: replacement, name: "復旧したプロファイル")) }
            for i in spaces.indices where spaces[i].profileID == zeroID { spaces[i].profileID = replacement }
        }
        // A missing profile record must not change a Space's login identity.
        // Its UUID still identifies the original WebKit data store, so restore
        // that record instead of connecting the Space to another user's store.
        var profileIDs = Set(profiles.map(\.id))
        for space in spaces where !profileIDs.contains(space.profileID) {
            profiles.append(BrowserProfile(id: space.profileID, name: "復旧したプロファイル"))
            profileIDs.insert(space.profileID)
        }
        if profiles.isEmpty { profiles = [BrowserProfile(name: "デフォルト")] }
        for i in profiles.indices { profiles[i].name = nonempty(profiles[i].name, fallback: "プロファイル") }
        if spaces.isEmpty { spaces = [BrowserSpace(name: "マイスペース", profileID: profiles[0].id)] }
        for i in spaces.indices {
            spaces[i].name = nonempty(spaces[i].name, fallback: "スペース")
            spaces[i].icon = nonempty(spaces[i].icon, fallback: "🌐")
            spaces[i].colorHex = normalizedColor(spaces[i].colorHex)
        }
        // If a Space record itself disappeared, its original profile cannot be
        // inferred. Recover its tabs under a new isolated profile, never the
        // first existing Space's cookies.
        var knownSpaceIDs = Set(spaces.map(\.id))
        let referencedSpaceIDs = tabs.map(\.spaceID) + archive.map(\.tab.spaceID) + folders.map(\.spaceID)
        for id in referencedSpaceIDs where !knownSpaceIDs.contains(id) {
            let profile = BrowserProfile(name: "復旧したプロファイル")
            profiles.append(profile)
            spaces.append(BrowserSpace(id: id, name: "復旧したスペース", profileID: profile.id))
            knownSpaceIDs.insert(id)
        }
        let spaceIDs = Set(spaces.map(\.id))
        if !spaceIDs.contains(selectedSpaceID) { selectedSpaceID = spaces[0].id }
        folders = unique(folders)
        for i in folders.indices {
            folders[i].name = nonempty(folders[i].name, fallback: "フォルダ")
        }
        var folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        for i in folders.indices {
            if let parent = folders[i].parentID,
               parent == folders[i].id || folderMap[parent]?.spaceID != folders[i].spaceID {
                folders[i].parentID = nil
            }
        }
        // Break every cycle deterministically, including cycles not reachable from a root.
        for i in folders.indices {
            folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
            var seen: Set<UUID> = [folders[i].id]
            var cursor = folders[i].parentID
            while let id = cursor {
                if !seen.insert(id).inserted { folders[i].parentID = nil; break }
                cursor = folderMap[id]?.parentID
            }
        }
        folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        func repairedTab(_ input: BrowserTab) -> BrowserTab {
            var tab = input
            tab.title = nonempty(tab.title, fallback: "新しいタブ")
            tab.customTitle = tab.customTitle.flatMap { trimmed($0).isEmpty ? nil : trimmed($0) }
            tab.url = nonempty(tab.url, fallback: "about:blank")
            tab.pinnedURL = tab.pinnedURL.flatMap { trimmed($0).isEmpty ? nil : trimmed($0) }
            if !tab.isPinned || tab.folderID.flatMap({ folderMap[$0]?.spaceID }) != tab.spaceID { tab.folderID = nil }
            return tab
        }
        tabs = unique(tabs).map(repairedTab)
        archive = unique(archive).map { entry in
            var entry = entry; entry.tab = repairedTab(entry.tab); return entry
        }.sorted { $0.archivedAt > $1.archivedAt }
        favorites = Array(unique(favorites).filter { !trimmed($0.url).isEmpty }.prefix(12))
        for i in favorites.indices {
            favorites[i].title = nonempty(favorites[i].title, fallback: favorites[i].url)
            favorites[i].url = trimmed(favorites[i].url)
        }
        if let selectedFavoriteID, favorites.contains(where: { $0.id == selectedFavoriteID }) {
            selectedTabID = nil; split = nil
        } else {
            selectedFavoriteID = nil
            if selectedTabID != nil && !tabs.contains(where: { $0.id == selectedTabID && $0.spaceID == selectedSpaceID }) {
                selectedTabID = tabs.first(where: { $0.spaceID == selectedSpaceID })?.id
            }
        }
        if var split {
            let IDs = Set(tabs.filter { $0.spaceID == selectedSpaceID }.map(\.id))
            if split.leadingTabID == split.trailingTabID || !IDs.contains(split.leadingTabID) || !IDs.contains(split.trailingTabID) {
                self.split = nil
            } else {
                split.fraction = split.fraction.isFinite ? min(0.8, max(0.2, split.fraction)) : 0.5
                self.split = split
                if selectedTabID != split.leadingTabID && selectedTabID != split.trailingTabID { selectedTabID = split.leadingTabID }
            }
        }
        return self == original ? [] : ["保存データの参照または値を修復しました。"]
    }
}

func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
func nonempty(_ value: String, fallback: String) -> String { let value = trimmed(value); return value.isEmpty ? fallback : value }
func normalizedColor(_ value: String) -> String {
    let value = trimmed(value).replacingOccurrences(of: "#", with: "")
    return value.count == 6 && value.allSatisfy(\.isHexDigit) ? value.uppercased() : "7896B8"
}
private func unique<T: Identifiable>(_ values: [T]) -> [T] where T.ID: Hashable {
    var seen = Set<T.ID>(); return values.filter { seen.insert($0.id).inserted }
}
