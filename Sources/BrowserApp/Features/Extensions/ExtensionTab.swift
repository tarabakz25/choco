import AppKit
import BrowserCore
import BrowserRuntime
import WebKit

/// Presents one browser tab to extensions. The tab exists for as long as the Core record does; its `WebSession`
/// comes and goes (never created at launch, released when hibernated), so reads fall back to the saved record.
@MainActor final class ExtensionTab: NSObject, WKWebExtensionTab {
    let id: UUID
    let profileID: UUID
    private(set) var session: WebSession?
    /// Whether extensions have been sent `didOpenTab` for this tab.
    var isAnnounced = false
    private unowned let host: ExtensionHost
    private var reportedURL: URL?
    private var reportedTitle: String
    private var reportedLoading: Bool

    init(id: UUID, profileID: UUID, session: WebSession?, host: ExtensionHost) {
        self.id = id
        self.profileID = profileID
        self.host = host
        self.session = session
        let record = host.record(for: id)
        reportedURL = session?.url ?? record.flatMap { URL(string: $0.url) }
        reportedTitle = session?.title ?? record?.displayTitle ?? ""
        reportedLoading = session?.isLoading ?? false
    }

    func attach(_ session: WebSession) { self.session = session }
    func detach() { session = nil }

    private var currentURL: URL? { session?.url ?? host.record(for: id).flatMap { URL(string: $0.url) } }
    private var currentTitle: String { session?.title ?? host.record(for: id)?.displayTitle ?? "" }

    /// The properties that differ from what extensions were last told, then remembered as reported.
    func takeChangedProperties() -> WKWebExtension.TabChangedProperties {
        var changed: WKWebExtension.TabChangedProperties = []
        if reportedURL != currentURL { changed.insert(.URL); reportedURL = currentURL }
        if reportedTitle != currentTitle { changed.insert(.title); reportedTitle = currentTitle }
        let loading = session?.isLoading ?? false
        if reportedLoading != loading { changed.insert(.loading); reportedLoading = loading }
        return changed
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? { host.window(for: profileID) }
    func indexInWindow(for context: WKWebExtensionContext) -> Int { host.index(of: self) }
    func webView(for context: WKWebExtensionContext) -> WKWebView? { session?.webView }
    func title(for context: WKWebExtensionContext) -> String? { currentTitle }
    func url(for context: WKWebExtensionContext) -> URL? { currentURL }
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool { !(session?.isLoading ?? false) }
    func isPinned(for context: WKWebExtensionContext) -> Bool { host.record(for: id)?.isPinned ?? false }
    func isSelected(for context: WKWebExtensionContext) -> Bool { host.isActive(self) }
    func size(for context: WKWebExtensionContext) -> CGSize { session?.webView.frame.size ?? .zero }
    func zoomFactor(for context: WKWebExtensionContext) -> Double { session.map { Double($0.webView.pageZoom) } ?? 1 }
    func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext) async throws { session?.webView.pageZoom = zoomFactor }
    func isMuted(for context: WKWebExtensionContext) -> Bool { false }
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool { true }

    // These need a live page, so an extension acting on an unmounted tab is what loads it.
    func loadURL(_ url: URL, for context: WKWebExtensionContext) async throws { try liveSession().navigate(to: url) }
    func reload(fromOrigin: Bool, for context: WKWebExtensionContext) async throws {
        let session = try liveSession()
        if fromOrigin { session.webView.reloadFromOrigin() } else { session.reload() }
    }
    func goBack(for context: WKWebExtensionContext) async throws { try liveSession().goBack() }
    func goForward(for context: WKWebExtensionContext) async throws { try liveSession().goForward() }
    func activate(for context: WKWebExtensionContext) async throws { host.activate(id) }
    func close(for context: WKWebExtensionContext) async throws { host.close(id) }

    private func liveSession() throws -> WebSession {
        if let session { return session }
        guard let live = host.mountSession(for: id) else { throw ExtensionHostError.cannotOpen }
        return live
    }
}

/// One window per profile: the browser window shows the tabs of whichever Space is selected.
@MainActor final class ExtensionWindow: NSObject, WKWebExtensionWindow {
    let profileID: UUID
    private unowned let host: ExtensionHost

    init(profileID: UUID, host: ExtensionHost) {
        self.profileID = profileID
        self.host = host
    }

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] { host.tabs(profileID: profileID) }
    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? { host.activeTab(profileID: profileID) }
    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType { .normal }
    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let window = host.presentationWindow else { return .normal }
        if window.isMiniaturized { return .minimized }
        return window.styleMask.contains(.fullScreen) ? .fullscreen : .normal
    }
    func isPrivate(for context: WKWebExtensionContext) -> Bool { false }
    func frame(for context: WKWebExtensionContext) -> CGRect { host.presentationWindow?.frame ?? .zero }
    func screenFrame(for context: WKWebExtensionContext) -> CGRect { host.presentationWindow?.screen?.frame ?? .zero }
    func focus(for context: WKWebExtensionContext) async throws { host.model?.showMainWindow() }
}

/// An extension page (for example a welcome page) opened as its own window rather than a browser tab.
@MainActor final class ExtensionPageTab: NSObject, WKWebExtensionTab {
    let webView: WKWebView
    private weak var pageWindow: ExtensionPageWindow?

    init(webView: WKWebView, window: ExtensionPageWindow) {
        self.webView = webView
        pageWindow = window
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? { webView }
    func title(for context: WKWebExtensionContext) -> String? { webView.title }
    func url(for context: WKWebExtensionContext) -> URL? { webView.url }
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool { !webView.isLoading }
    func close(for context: WKWebExtensionContext) async throws { pageWindow?.close() }
}
