import AppKit
import BrowserCore
import BrowserRuntime
import SwiftUI

/// A tab dragged out of the browser window. It keeps the live `WebSession` (history, scroll, logins)
/// and, once closed, goes to the archive so it can be restored like any other closed tab.
@MainActor final class DetachedTabWindow: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 960, height: 680)
    private unowned let model: AppModel
    private var tab: BrowserTab
    let session: WebSession
    private(set) var window: NSWindow?
    private var isFinished = false

    init(model: AppModel, tab: BrowserTab, session: WebSession) {
        self.model = model; self.tab = tab; self.session = session
        super.init()
    }

    /// Places the window so the pointer sits on its toolbar, kept inside the screen under the pointer.
    func show(near point: NSPoint) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        TrafficLightInset.install(on: window, inset: 6, scale: ChocoSpace.scale)
        window.backgroundColor = NSColor(red: 94 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1)
        window.contentMinSize = NSSize(width: 480, height: 320)
        window.title = tab.displayTitle
        window.delegate = self
        window.contentView = NSHostingView(rootView: DetachedTabView(session: session) { [weak window] title in
            window?.title = title
        })
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var frame = NSRect(x: point.x - 90, y: point.y - Self.size.height + 24, width: Self.size.width, height: Self.size.height)
        if let visible = screen?.visibleFrame {
            frame.size.width = min(frame.width, visible.width); frame.size.height = min(frame.height, visible.height)
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: false)
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { finish(closingWindow: false) }

    /// Archives the tab at its last address and releases the page. Safe to call more than once.
    func finish(closingWindow: Bool = true) {
        guard !isFinished else { return }
        isFinished = true
        if let url = session.url?.absoluteString, !url.isEmpty { tab.url = url }
        if !session.title.isEmpty { tab.title = session.title }
        model.send(.archiveTab(tab))
        model.releaseDetached(tab.id)
        session.dispose()
        window?.delegate = nil
        window?.contentView = nil
        if closingWindow { window?.close() }
        window = nil
    }
}

private struct DetachedTabView: View {
    @Environment(\.spaceTheme) private var theme
    let session: WebSession
    let onTitleChange: (String) -> Void

    var body: some View {
        VStack(spacing: ChocoSpace.u(6)) {
            toolbar
            ZStack {
                ChocoTheme.content
                WebViewMount(webView: session.webView) {}
                if let message = session.errorMessage {
                    VStack(spacing: ChocoSpace.md) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                        Text("ページを開けませんでした").font(.headline)
                        Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("再試行") { session.reload() }.buttonStyle(.borderedProminent)
                    }.padding(ChocoSpace.u(30)).frame(maxWidth: ChocoSpace.u(480))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ChocoTheme.contentRadius))
            .padding([.horizontal, .bottom], ChocoTheme.contentInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.sidebar)
        .foregroundStyle(ChocoTheme.text)
        .font(ChocoTheme.font(13))
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: session.title, initial: true) { _, title in onTitleChange(title) }
        .accessibilityIdentifier("detached-tab-window")
    }

    private var address: String {
        guard let url = session.url, url.absoluteString != "about:blank" else { return "新しいタブ" }
        return (url.host ?? url.absoluteString) + (url.path == "/" ? "" : url.path)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            // The native traffic lights sit here; the window draws none of its own.
            Color.clear.frame(width: 76, height: 12).accessibilityHidden(true)
            Button { session.goBack() } label: { DesignIcon("687ab", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .disabled(!session.canGoBack).help("戻る").accessibilityLabel("戻る")
            Button { session.goForward() } label: { DesignIcon("caa3a", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28) }
                .disabled(!session.canGoForward).help("進む").accessibilityLabel("進む")
            Button { session.isLoading ? session.stop() : session.reload() } label: {
                DesignIcon("108be", size: 16).opacity(0.62).frame(width: ChocoSpace.u(28), height: 28)
            }
            .help(session.isLoading ? "読み込みを中止" : "再読み込み")
            .accessibilityLabel(session.isLoading ? "読み込みを中止" : "再読み込み")
            HStack(spacing: ChocoSpace.u(6)) {
                SiteIcon(url: session.url?.absoluteString ?? "", size: 13)
                Text(address).font(ChocoTheme.font(13)).foregroundStyle(ChocoTheme.secondary)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(28))
            .background(theme.field, in: RoundedRectangle(cornerRadius: 8))
            .padding(.leading, ChocoSpace.sm).padding(.trailing, ChocoSpace.sm)
        }
        .buttonStyle(ChocoPressStyle())
        .padding(.leading, ChocoSpace.u(6))
        .frame(height: 28)
        .padding(.top, 6)
    }
}
