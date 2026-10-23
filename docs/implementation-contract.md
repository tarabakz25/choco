# Alpha implementation contract

Ownership: core agent owns Sources/BrowserCore and Tests/BrowserCoreTests; runtime agent owns Sources/BrowserRuntime and Tests/BrowserRuntimeTests; UI agent owns Sources/BrowserApp. Coordinator owns Package.swift, project/build setup, docs, fixtures and integration. Agents must not revert others' work. Public API amendments must be communicated before consumers are changed.

## BrowserCore (Swift + Foundation + Observation only)

Public Codable, Equatable, Sendable models with UUID IDs:
- BrowserProfile: id, name (id is also persistent WKWebsiteDataStore identifier).
- BrowserSpace: id, name, icon (emoji String), colorHex (String), profileID.
- BrowserTab: id, spaceID, folderID (optional), title, customTitle (optional), url (String), pinnedURL (optional String); displayTitle computed; isPinned computed.
- BrowserFolder: id, spaceID, parentID (optional), name.
- BrowserFavorite: id, title, url (String). Max 12; global definitions. Runtime ID for favorite sessions is stable per favorite/profile, never inserted into normal tabs.
- ArchiveEntry: id, tab (BrowserTab), archivedAt (Date).
- SplitState: leadingTabID, trailingTabID, fraction (Double).
- BrowserState: schemaVersion, profiles, spaces, tabs (array order is sidebar order), folders, favorites, archive, selectedSpaceID, selectedTabID (optional), selectedFavoriteID (optional), split (optional), sidebarVisible. Supply initial default profile/space and blank initial tab. Expose selectedSpace and selectedProfile.

@MainActor @Observable public final class BrowserStore:
- public private(set) var state: BrowserState; public private(set) var persistenceError: String?
- init(directory: URL? = nil): nil uses Application Support/OssArc, tests inject temporary directory. Synchronous initial read, serial/atomic saves. Validation handles dangling references, corrupt/unsupported files without overwriting originals; backup and visible error recovery. Persistence API can be adjusted by owner with prompt notice.
- send(_ action: BrowserAction), flush() async; updatePage(tabID: UUID, url: String?, title: String?)
- BrowserAction cases: newTab(url: String), newTabWithID(id: UUID, spaceID: UUID, url: String), selectTab(UUID), selectFavorite(UUID), closeTab(UUID), restoreLatestArchive, restoreArchive(UUID), renameTab(UUID, String), duplicateTab(UUID), pinTab(UUID), unpinTab(UUID), resetPinnedTab(UUID), setPinnedURL(UUID, String), moveTab(UUID, spaceID: UUID, folderID: UUID?), moveTabBefore(UUID, beforeID: UUID?), createFolder(name: String, parentID: UUID?), renameFolder(UUID, String), moveFolder(UUID, parentID: UUID?, beforeID: UUID?), deleteFolder(UUID), createSpace(name: String, icon: String, colorHex: String, profileID: UUID), updateSpace(UUID, name: String, icon: String, colorHex: String, profileID: UUID), selectSpace(UUID), createProfile(name: String), createFavorite(title: String, url: String), updateFavorite(UUID, title: String, url: String), deleteFavorite(UUID), clearToday, setSplit(leading: UUID, trailing: UUID), swapSplit, setSplitFraction(Double), clearSplit, toggleSidebar.

Semantics: Today close archives; pinned close retains registration and selects another page (no deletion); unpin returns to Today; explicit deletion of a pinned record may use additional deleteTab action. Reset uses pinnedURL. Folders only contain pinned tabs. Deleting folder reparents children to parent. Split references existing same-space tab IDs, never copies tabs; archiving/moving a member collapses split. Favorite selection clears normal selection and split; favorite URL definitions shared, runtime browsing per-profile. Moving across profile replaces runtime session, never copies cookies. UI may add extra core actions through agreement. Profile deletion and space deletion are beta, do not expose dead controls.

## BrowserRuntime (WebKit + AppKit + Observation)

@MainActor @Observable public final class WebSession:
- public let id: UUID; public let profileID: UUID; public let webView: WKWebView
- public private(set) var url: URL?; title: String; isLoading: Bool; estimatedProgress: Double; canGoBack: Bool; canGoForward: Bool; errorMessage: String?
- init(id: UUID, profileID: UUID, initialURL: URL? = nil, configuration: WKWebViewConfiguration? = nil)
- navigate(to: URL), goBack(), goForward(), reload(), stop(), find(_ text: String, backwards: Bool = false), clearError()
- var onPageChange: ((URL?, String) -> Void)?; var onOpenWindow: ((WKWebViewConfiguration, URL?) -> WKWebView?)?; var onClose: (() -> Void)?
- adopt passed popup configuration. Provide native JS dialogs, file upload chooser, safe downloads via WKDownload save dialog; request media permission via standard prompt; retain TLS defaults and no private APIs. Expose isInspectable only for development. Parent/root may adjust delegate wiring for app integration.
- Lifecycle: observation must not retain cycles; stop and invalidate observers on disposal. SwiftUI never recreates a session on redraw.

@MainActor public final class WebSessionPool:
- init(); session(id: UUID, profileID: UUID, initialURL: URL? = nil) -> WebSession; remove(id: UUID); retainOnly(_ ids: Set<UUID>).
- existing session with same ID but different profile is discarded/replaced.

URL input normalization shared runtime helper: public enum AddressResolver { public static func resolve(_ input: String) -> URL? } : accept HTTP/HTTPS and hostnames/localhost (HTTPS except localhost HTTP); other text becomes DuckDuckGo search; reject explicitly dangerous schemes (javascript/data/file); empty -> nil. No remote suggestions.

## SwiftUI BrowserApp

Single Window scene + Settings, @main app. App coordinator holds BrowserStore and WebSessionPool. NSViewRepresentable only mounts an existing session.webView. Observe core changes to dispose closed/profile-changed sessions; URL/title callbacks update core without navigation loops. Cache favorite runtime session keys per favorite/profile. Popup callbacks create a normal Today tab in originating space/profile, returning a WKWebView using supplied configuration.

Arc-like compact sidebar: 260pt initial adjustable width; global favorites, spaces, pinned folder tree, Today. Native SF typography, semantic colors and subtle per-space tint, central command overlay. All main controls functional, no fake feature menu. Japanese interface strings. Context menus/sheets for profile/space/folder/tab management. Folder/space creation forms use sheets. Command overlay handles Cmd+T (create) and Cmd+L (navigate active), existing tab search current space first, action commands, keyboard arrows/enter/escape; no web access until explicit search/navigation. Two-pane HSplitView, swap and close, remembered fraction. Archive sheet and restore action. Standard back/forward/reload/find/sidebar shortcuts. Defaults keyboard accessibility, reduced motion, keyboard focus, visible errors. Send all state operations through actions.

## Integration amendments

Popup adoption is `adopt(id:profileID:configuration:) -> WebSession?`: alpha requires a matching persistent data-store identifier. Reject stale/mismatched callbacks before state insertion; use newTabWithID after successful adoption. Invalid saved Profile references recover their own namespace rather than using the first existing Profile. Missing Space references recover into a fresh isolated Profile.

Cmd+L defaults to current-page navigation even when another Space has a matching URL; switching to suggestions requires explicit arrow/click. Cmd+T may prefer existing tabs.
