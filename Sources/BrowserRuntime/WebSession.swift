import AppKit
import BrowserLocalization
import Foundation
import Observation
import WebKit

@MainActor @Observable
public final class WebSession: NSObject {
    public let id: UUID
    public let profileID: UUID
    public let webView: WKWebView
    public private(set) var url: URL?
    // Page titles remain content; the app supplies its localized empty-tab label.
    public private(set) var title = ""
    public private(set) var isLoading = false
    public private(set) var estimatedProgress = 0.0
    public private(set) var canGoBack = false
    public private(set) var canGoForward = false
    public private(set) var errorMessage: String?
    public private(set) var activeDownloadCount = 0
    public private(set) var downloadProgress: Double?

    @ObservationIgnored public var onPageChange: ((URL?, String) -> Void)?
    @ObservationIgnored public var onOpenWindow: ((WKWebViewConfiguration, URL?) -> WKWebView?)?
    @ObservationIgnored public var onClose: (() -> Void)?
    /// The user pressed the "Add to Choco" button on a Chrome Web Store detail page. Carries the page URL and title.
    @ObservationIgnored public var onStoreInstallRequest: ((URL, String) -> Void)?
    /// Fires after any observed page state (URL, title, loading, history) changed.
    @ObservationIgnored public var onStateChange: ((WebSession) -> Void)?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var downloads: [ObjectIdentifier: DownloadTransfer] = [:]
    @ObservationIgnored private var isDisposed = false
    @ObservationIgnored private var hasStoreBridge = false
    @ObservationIgnored private var lastReportedURL: URL?
    @ObservationIgnored private var lastReportedTitle = ""
    @ObservationIgnored private var pendingScroll: PageScrollOffset?

    public init(id: UUID, profileID: UUID, initialURL: URL? = nil, restoreScroll: PageScrollOffset? = nil, configuration: WKWebViewConfiguration? = nil,
                extensionController: WKWebExtensionController? = nil, installsStoreBridge: Bool = true) {
        self.id = id
        self.profileID = profileID
        let hasInvalidProfileIdentifier = profileID.uuidString == "00000000-0000-0000-0000-000000000000"
        let configuration = configuration ?? {
            let configuration = WKWebViewConfiguration()
            configuration.applyBrowserIdentity()
            // WebKit raises an Objective-C exception for the zero UUID. A
            // corrupt profile must never crash the app or use another profile.
            configuration.websiteDataStore = hasInvalidProfileIdentifier ? .nonPersistent() : WKWebsiteDataStore(forIdentifier: profileID)
            configuration.webExtensionController = extensionController
            return configuration
        }()
        if let extensionController { configuration.webExtensionController = extensionController }
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // A popup shares its opener's content controller, which already carries the bridge (and a second handler of the same name would raise).
        if installsStoreBridge { installStoreBridge() }
        if hasInvalidProfileIdentifier {
            errorMessage = Localizer().text("The profile identifier is invalid. Login information for this tab will not be saved. Create a new profile.")
        }
        #if DEBUG
        webView.isInspectable = true
        #endif
        observeWebView()
        if let initialURL { navigate(to: initialURL, restoreScroll: restoreScroll) }
    }

    public func navigate(to url: URL) {
        navigate(to: url, restoreScroll: nil)
    }

    /// Reads scroll, media playback, and unsaved form edits. Nil means the page could not be asked.
    public func capturePageMemory() async -> PageMemoryProbe? {
        guard !isDisposed else { return nil }
        do {
            let value = try await webView.evaluateJavaScript(PageMemoryScript.source)
            return PageMemoryScript.decode(value: value)
        } catch {
            return nil
        }
    }

    public func navigate(to url: URL, restoreScroll: PageScrollOffset?) {
        guard !isDisposed else { return }
        guard Self.isWebNavigation(url) else {
            pendingScroll = nil
            errorMessage = Localizer().text("This type of URL cannot be opened. Enter an HTTP or HTTPS URL.")
            return
        }
        pendingScroll = restoreScroll
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    public func goBack() { if !isDisposed { errorMessage = nil; webView.goBack() } }
    public func goForward() { if !isDisposed { errorMessage = nil; webView.goForward() } }
    public func reload() { if !isDisposed { errorMessage = nil; webView.reload() } }
    public func stop() { webView.stopLoading() }
    public func clearError() { errorMessage = nil }

    public func find(_ text: String, backwards: Bool = false) {
        guard !isDisposed else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(text, configuration: configuration) { _ in }
    }

    /// Called by the pool before a closed or profile-reassigned session is discarded.
    public func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        if hasStoreBridge { webView.configuration.userContentController.removeScriptMessageHandler(forName: StoreInstallBridge.handlerName) }
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        for transfer in downloads.values {
            transfer.progressObservation?.invalidate()
            transfer.download.delegate = nil
            transfer.download.cancel { _ in }
            transfer.cleanUp()
        }
        downloads.removeAll()
        activeDownloadCount = 0
        downloadProgress = nil
        pendingScroll = nil
        onPageChange = nil
        onOpenWindow = nil
        onClose = nil
        onStateChange = nil
        onStoreInstallRequest = nil
    }

    /// Tells a Web Store page that the install it requested has ended, so its button stops showing progress.
    public func finishStoreInstall() {
        guard !isDisposed else { return }
        webView.evaluateJavaScript("window.__chocoStoreInstallFinished && window.__chocoStoreInstallFinished()") { _, _ in }
    }

    private func installStoreBridge() {
        let controller = webView.configuration.userContentController
        controller.addUserScript(StoreInstallBridge.makeScript())
        controller.add(StoreInstallMessageHandler { [weak self] message in
            // Only a real store detail page in the main frame may start an install, whatever the page's script claims.
            guard let self, message.frameInfo.isMainFrame, let url = message.frameInfo.request.url,
                  ChromeWebStore.storeDetailID(of: url) != nil else { return }
            self.onStoreInstallRequest?(url, self.webView.title ?? "")
        }, name: StoreInstallBridge.handlerName)
        hasStoreBridge = true
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() }
        ]
    }

    nonisolated private func scheduleUpdate() {
        Task { @MainActor [weak self] in self?.updateState() }
    }

    private func updateState() {
        guard !isDisposed else { return }
        url = webView.url
        title = webView.title.flatMap { $0.isEmpty ? nil : $0 } ?? webView.url?.host ?? ""
        isLoading = webView.isLoading
        estimatedProgress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if lastReportedURL != url || lastReportedTitle != title {
            lastReportedURL = url
            lastReportedTitle = title
            onPageChange?(url, title)
        }
        onStateChange?(self)
    }

    private static func isWebNavigation(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return ((scheme == "http" || scheme == "https") && url.host != nil) || url.absoluteString == "about:blank"
    }

    private func present(_ alert: NSAlert, completion: @escaping @MainActor @Sendable (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private func siteAlert(message: String, frame: WKFrameInfo) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host.isEmpty ? Localizer().text("Message from a Web Page") : frame.securityOrigin.host
        alert.informativeText = message
        return alert
    }

    private func beginTracking(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard downloads[key] == nil else { return }
        let transfer = DownloadTransfer(download: download)
        downloads[key] = transfer
        download.delegate = self
        transfer.progressObservation = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateDownloadProgress() }
        }
        updateDownloadProgress()
    }

    private func updateDownloadProgress() {
        activeDownloadCount = downloads.count
        let fractions = downloads.values.map { $0.download.progress.fractionCompleted }
        downloadProgress = fractions.isEmpty ? nil : fractions.reduce(0, +) / Double(fractions.count)
    }

    private func finishTracking(_ download: WKDownload) {
        guard let transfer = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        transfer.progressObservation?.invalidate()
        download.delegate = nil
        transfer.cleanUp()
        updateDownloadProgress()
    }
}

extension WebSession: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard !isDisposed, let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        // Embedded documents legitimately use opaque data origins and srcdoc.
        // These are web content, not addresses entered into the browser shell.
        if navigationAction.targetFrame?.isMainFrame == false,
           url.scheme?.lowercased() == "data" || url.absoluteString == "about:srcdoc" {
            decisionHandler(.allow)
            return
        }
        if Self.isWebNavigation(url) || url.scheme?.lowercased() == "blob" {
            decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated,
                  ["mailto", "tel", "sms"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        } else {
            decisionHandler(.cancel)
            errorMessage = Localizer().text("This type of link cannot be opened in this browser.")
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { beginTracking(download) }
    public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { beginTracking(download) }
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { errorMessage = nil; updateState() }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateState()
        applyPendingScroll()
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { reportNavigationError(error) }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { reportNavigationError(error) }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = Localizer().text("The page stopped responding. Reload to continue.")
        updateState()
    }

    private func applyPendingScroll() {
        guard let pendingScroll, !isDisposed, !webView.isLoading else { return }
        let x = Self.jsNumber(pendingScroll.x)
        let y = Self.jsNumber(pendingScroll.y)
        self.pendingScroll = nil
        let script = "window.scrollTo(\(x), \(y));"
        Task { @MainActor [weak self] in
            guard let self, !self.isDisposed else { return }
            _ = try? await self.webView.evaluateJavaScript(script)
        }
    }

    private static func jsNumber(_ value: Double) -> String {
        let number = value.isFinite ? max(0, value) : 0
        return String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), number)
    }

    private func reportNavigationError(_ error: Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        errorMessage = Localizer().format("Could not open the page: %@", error.localizedDescription)
        updateState()
    }
}

extension WebSession: WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !isDisposed else { return nil }
        return onOpenWindow?(configuration, navigationAction.request.url)
    }

    public func webViewDidClose(_ webView: WKWebView) { onClose?() }

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = siteAlert(message: message, frame: frame)
        alert.addButton(withTitle: Localizer().text("OK"))
        present(alert) { _ in completionHandler() }
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        let alert = siteAlert(message: message, frame: frame)
        alert.addButton(withTitle: Localizer().text("OK"))
        alert.addButton(withTitle: Localizer().text("Cancel"))
        present(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        let alert = siteAlert(message: prompt, frame: frame)
        alert.addButton(withTitle: Localizer().text("OK"))
        alert.addButton(withTitle: Localizer().text("Cancel"))
        let field = NSTextField(string: defaultText ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = field
        present(alert) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }

    public func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        let completion: @MainActor @Sendable (NSApplication.ModalResponse) -> Void = { response in completionHandler(response == .OK ? panel.urls : nil) }
        if let window = webView.window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }
}

extension WebSession: WKDownloadDelegate {
    public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        beginTracking(download)
        guard let transfer = downloads[ObjectIdentifier(download)] else { completionHandler(nil); return }
        let panel = NSSavePanel()
        let filename = (suggestedFilename as NSString).lastPathComponent
        panel.nameFieldStringValue = filename.isEmpty || filename == "." || filename == ".." ? "download" : filename
        panel.canCreateDirectories = true
        panel.title = Localizer().text("Save Download")
        let completion: @MainActor @Sendable (NSApplication.ModalResponse) -> Void = { [weak self] result in
            guard let self, !self.isDisposed, result == .OK, let destination = panel.url else {
                completionHandler(nil)
                self?.finishTracking(download)
                return
            }
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OssArcDownload-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let staging = directory.appendingPathComponent("payload")
                transfer.temporaryDirectory = directory
                transfer.stagingURL = staging
                transfer.destinationURL = destination
                transfer.hasSecurityScope = destination.startAccessingSecurityScopedResource()
                completionHandler(staging)
            } catch {
                self.errorMessage = Localizer().format("Could not prepare the download destination: %@", error.localizedDescription)
                completionHandler(nil)
                self.finishTracking(download)
            }
        }
        if let window = webView.window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    public func downloadDidFinish(_ download: WKDownload) {
        defer { finishTracking(download) }
        guard let transfer = downloads[ObjectIdentifier(download)], let staging = transfer.stagingURL, let destination = transfer.destinationURL else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
            } else {
                try FileManager.default.copyItem(at: staging, to: destination)
            }
        } catch {
            errorMessage = Localizer().format("Could not save the download: %@", error.localizedDescription)
        }
    }

    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if (error as NSError).code != NSURLErrorCancelled {
            errorMessage = Localizer().format("Download failed: %@", error.localizedDescription)
        }
        finishTracking(download)
    }
}

@MainActor
private final class DownloadTransfer {
    let download: WKDownload
    var progressObservation: NSKeyValueObservation?
    var destinationURL: URL?
    var stagingURL: URL?
    var temporaryDirectory: URL?
    var hasSecurityScope = false

    init(download: WKDownload) { self.download = download }

    func cleanUp() {
        if hasSecurityScope { destinationURL?.stopAccessingSecurityScopedResource(); hasSecurityScope = false }
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
    }
}
