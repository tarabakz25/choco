import AppKit
import BrowserCore
import BrowserRuntime
import WebKit

/// Presents one `WebSession` to extensions as a browser tab.
@MainActor final class ExtensionTab: NSObject, WKWebExtensionTab {
    let session: WebSession
    private unowned let host: ExtensionHost
    private var reportedURL: URL?
    private var reportedTitle: String
    private var reportedLoading: Bool

    init(session: WebSession, host: ExtensionHost) {
        self.session = session
        self.host = host
        reportedURL = session.url
        reportedTitle = session.title
        reportedLoading = session.isLoading
    }

    /// The properties that differ from what extensions were last told, then remembered as reported.
    func takeChangedProperties() -> WKWebExtension.TabChangedProperties {
        var changed: WKWebExtension.TabChangedProperties = []
        if reportedURL != session.url { changed.insert(.URL); reportedURL = session.url }
        if reportedTitle != session.title { changed.insert(.title); reportedTitle = session.title }
        if reportedLoading != session.isLoading { changed.insert(.loading); reportedLoading = session.isLoading }
        return changed
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? { host.window(for: session.profileID) }
    func indexInWindow(for context: WKWebExtensionContext) -> Int { host.index(of: self) }
    func webView(for context: WKWebExtensionContext) -> WKWebView? { session.webView }
    func title(for context: WKWebExtensionContext) -> String? { session.title }
    func url(for context: WKWebExtensionContext) -> URL? { session.url }
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool { !session.isLoading }
    func isPinned(for context: WKWebExtensionContext) -> Bool { host.isPinned(session) }
    func isSelected(for context: WKWebExtensionContext) -> Bool { host.isActive(self) }
    func size(for context: WKWebExtensionContext) -> CGSize { session.webView.frame.size }
    func zoomFactor(for context: WKWebExtensionContext) -> Double { session.webView.pageZoom }
    func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext) async throws { session.webView.pageZoom = zoomFactor }
    func isMuted(for context: WKWebExtensionContext) -> Bool { false }
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool { true }

    func loadURL(_ url: URL, for context: WKWebExtensionContext) async throws { session.navigate(to: url) }
    func reload(fromOrigin: Bool, for context: WKWebExtensionContext) async throws {
        if fromOrigin { session.webView.reloadFromOrigin() } else { session.reload() }
    }
    func goBack(for context: WKWebExtensionContext) async throws { session.goBack() }
    func goForward(for context: WKWebExtensionContext) async throws { session.goForward() }
    func activate(for context: WKWebExtensionContext) async throws { host.activate(session) }
    func close(for context: WKWebExtensionContext) async throws { host.close(session) }
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
