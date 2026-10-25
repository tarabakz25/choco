import Foundation
import BrowserLocalization

public struct BrowserProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}

public struct BrowserSpace: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var profileID: UUID
    public init(id: UUID = UUID(), name: String, icon: String = "🌐", colorHex: String = "7896B8", profileID: UUID) {
        self.id = id; self.name = name; self.icon = icon; self.colorHex = colorHex; self.profileID = profileID
    }
}

public struct BrowserTab: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var spaceID: UUID
    public var folderID: UUID?
    public var title: String
    public var customTitle: String?
    public var url: String
    public var pinnedURL: String?
    public var displayTitle: String { customTitle.flatMap { $0.isEmpty ? nil : $0 } ?? title }
    public var isPinned: Bool { pinnedURL != nil }
    public init(id: UUID = UUID(), spaceID: UUID, folderID: UUID? = nil, title: String = "新しいタブ", customTitle: String? = nil, url: String = "about:blank", pinnedURL: String? = nil) {
        self.id = id; self.spaceID = spaceID; self.folderID = folderID; self.title = title
        self.customTitle = customTitle; self.url = url; self.pinnedURL = pinnedURL
    }
}

public struct BrowserFolder: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var spaceID: UUID
    public var parentID: UUID?
    public var name: String
    public init(id: UUID = UUID(), spaceID: UUID, parentID: UUID? = nil, name: String) {
        self.id = id; self.spaceID = spaceID; self.parentID = parentID; self.name = name
    }
}

public struct BrowserFavorite: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var url: String
    public init(id: UUID = UUID(), title: String, url: String) { self.id = id; self.title = title; self.url = url }
}

public struct ArchiveEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var tab: BrowserTab
    public var archivedAt: Date
    public init(id: UUID = UUID(), tab: BrowserTab, archivedAt: Date = Date()) {
        self.id = id; self.tab = tab; self.archivedAt = archivedAt
    }
}

public struct SplitState: Codable, Equatable, Sendable {
    public var leadingTabID: UUID
    public var trailingTabID: UUID
    public var fraction: Double
    public init(leadingTabID: UUID, trailingTabID: UUID, fraction: Double = 0.5) {
        self.leadingTabID = leadingTabID; self.trailingTabID = trailingTabID; self.fraction = fraction
    }
}

public struct BrowserState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var profiles: [BrowserProfile]
    public var spaces: [BrowserSpace]
    public var tabs: [BrowserTab]
    public var folders: [BrowserFolder]
    public var favorites: [BrowserFavorite]
    public var archive: [ArchiveEntry]
    public var selectedSpaceID: UUID
    public var selectedTabID: UUID?
    public var selectedFavoriteID: UUID?
    public var split: SplitState?
    public var sidebarVisible: Bool
    public var selectedSpace: BrowserSpace? { spaces.first { $0.id == selectedSpaceID } }
    public var selectedProfile: BrowserProfile? { selectedSpace.flatMap { space in profiles.first { $0.id == space.profileID } } }

    public init(schemaVersion: Int = Self.currentSchemaVersion, profiles: [BrowserProfile], spaces: [BrowserSpace], tabs: [BrowserTab] = [], folders: [BrowserFolder] = [], favorites: [BrowserFavorite] = [], archive: [ArchiveEntry] = [], selectedSpaceID: UUID, selectedTabID: UUID? = nil, selectedFavoriteID: UUID? = nil, split: SplitState? = nil, sidebarVisible: Bool = true) {
        self.schemaVersion = schemaVersion; self.profiles = profiles; self.spaces = spaces; self.tabs = tabs
        self.folders = folders; self.favorites = favorites; self.archive = archive; self.selectedSpaceID = selectedSpaceID
        self.selectedTabID = selectedTabID; self.selectedFavoriteID = selectedFavoriteID; self.split = split; self.sidebarVisible = sidebarVisible
    }

    public static func initial() -> BrowserState {
        let profile = BrowserProfile(name: Localizer().text("Default"))
        let space = BrowserSpace(name: Localizer().text("My Space"), profileID: profile.id)
        let tab = BrowserTab(spaceID: space.id)
        return BrowserState(profiles: [profile], spaces: [space], tabs: [tab], selectedSpaceID: space.id, selectedTabID: tab.id)
    }
}

public enum BrowserAction: Sendable {
    case newTab(url: String)
    case newTabWithID(id: UUID, spaceID: UUID, url: String)
    case selectTab(UUID), selectFavorite(UUID), closeTab(UUID), deleteTab(UUID)
    case restoreLatestArchive, restoreArchive(UUID)
    case renameTab(UUID, String), duplicateTab(UUID), pinTab(UUID), unpinTab(UUID), resetPinnedTab(UUID), setPinnedURL(UUID, String)
    case moveTab(UUID, spaceID: UUID, folderID: UUID?)
    case moveTabBefore(UUID, beforeID: UUID?)
    case createFolder(name: String, parentID: UUID?), renameFolder(UUID, String), deleteFolder(UUID)
    case moveFolder(UUID, parentID: UUID?, beforeID: UUID?)
    case createSpace(name: String, icon: String, colorHex: String, profileID: UUID)
    case updateSpace(UUID, name: String, icon: String, colorHex: String, profileID: UUID)
    case selectSpace(UUID), createProfile(name: String)
    case createFavorite(title: String, url: String), updateFavorite(UUID, title: String, url: String), deleteFavorite(UUID)
    case clearToday
    case setSplit(leading: UUID, trailing: UUID), swapSplit, setSplitFraction(Double), clearSplit, toggleSidebar
}
