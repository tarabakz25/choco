import AppKit
import WebKit

/// Hosts an extension's own page, such as its options, in a window that can use the extension APIs.
@MainActor final class ExtensionPageWindow: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 760, height: 620)
    let webView: WKWebView
    private let window: NSWindow
    private var titleObservation: NSKeyValueObservation?
    private let onClose: (ExtensionPageWindow) -> Void

    init?(context: WKWebExtensionContext, url: URL, onClose: @escaping (ExtensionPageWindow) -> Void) {
        guard let configuration = context.webViewConfiguration else { return nil }
        webView = WKWebView(frame: NSRect(origin: .zero, size: Self.size), configuration: configuration)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        self.onClose = onClose
        super.init()
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.title = context.webExtension.displayName ?? "拡張機能"
        window.delegate = self
        titleObservation = webView.observe(\.title) { [weak self] webView, _ in
            MainActor.assumeIsolated { if let title = webView.title, !title.isEmpty { self?.window.title = title } }
        }
        webView.load(URLRequest(url: url))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        titleObservation?.invalidate()
        webView.stopLoading()
        window.delegate = nil
        onClose(self)
    }
}
