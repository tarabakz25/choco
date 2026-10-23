import AppKit
import BrowserCore
import BrowserRuntime
import SwiftUI
import WebKit

struct BrowserWindow: View {
    @Bindable var model: AppModel
    @State private var sidebarWidth: CGFloat = 260
    @State private var sidebarDragStart: CGFloat?
    @State private var splitDragStart: Double?
    @FocusState private var findFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if model.state.sidebarVisible {
                    BrowserSidebar(model: model)
                        .frame(width: sidebarWidth)
                    Rectangle().fill(.clear).frame(width: 5)
                        .contentShape(Rectangle())
                        .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            if sidebarDragStart == nil { sidebarDragStart = sidebarWidth }
                            sidebarWidth = min(380, max(210, (sidebarDragStart ?? 260) + value.translation.width))
                        }.onEnded { _ in sidebarDragStart = nil })
                        .accessibilityLabel("サイドバーの幅")
                }
                VStack(spacing: 0) {
                    toolbar
                    if model.showsFind { findBar }
                    if let session = model.activeSession, session.activeDownloadCount > 0 {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("ダウンロード中 · \(session.activeDownloadCount)件")
                            if let progress = session.downloadProgress { ProgressView(value: progress).frame(width: 100) }
                            Spacer()
                        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 6)
                    }
                    content
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 8).padding(.trailing, 8).padding(.bottom, 8)
                .padding(.leading, model.state.sidebarVisible ? 0 : 8)
            }
            .background(model.tint.opacity(0.16))
            if model.commandMode != nil {
                Color.black.opacity(0.24).ignoresSafeArea().onTapGesture { model.commandMode = nil }
                CommandPalette(model: model)
                    .frame(width: 620)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 100)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(WindowReference { model.browserWindow = $0 })
        .tint(model.tint)
        .sheet(item: $model.editor) { request in EditorSheet(model: model, request: request) }
        .sheet(isPresented: $model.showsArchive) { ArchiveSheet(model: model) }
        .onChange(of: model.store.state) { _, _ in model.reconcile() }
        .onAppear { model.reconcile() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let error = model.store.persistenceError {
                Label(error, systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption).padding(8).frame(maxWidth: .infinity)
                    .background(.red.opacity(0.12)).foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            if !model.state.sidebarVisible {
                Color.clear.frame(width: 64, height: 20)
                Button { model.send(.toggleSidebar) } label: { Image(systemName: "sidebar.left") }
                    .help("サイドバーを表示 (⌘S)")
            }
            Button { model.activeSession?.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!(model.activeSession?.canGoBack ?? false)).help("戻る (⌘[)")
            Button { model.activeSession?.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!(model.activeSession?.canGoForward ?? false)).help("進む (⌘])")
            Button {
                guard let session = model.activeSession else { return }
                session.isLoading ? session.stop() : session.reload()
            } label: { Image(systemName: model.activeSession?.isLoading == true ? "xmark" : "arrow.clockwise") }
                .help("再読み込み (⌘R)")
            Button { model.showCommand(.navigate) } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.activeSession?.url?.scheme == "https" ? "lock" : "globe")
                        .font(.caption2)
                    Text(displayAddress).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text("⌘L").font(.caption).foregroundStyle(.tertiary)
                }.foregroundStyle(.secondary).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).accessibilityLabel("アドレスを入力").accessibilityIdentifier("current-url").accessibilityValue(displayAddress)
            if model.state.split != nil {
                Button { model.send(.swapSplit) } label: { Image(systemName: "arrow.left.arrow.right") }.help("分割を入れ替える").accessibilityIdentifier("split-swap")
                Button { model.send(.clearSplit) } label: { Image(systemName: "rectangle") }.help("分割を解除").accessibilityIdentifier("split-clear")
            } else {
                Menu {
                    ForEach(model.state.tabs.filter { $0.spaceID == model.state.selectedSpaceID && $0.id != model.state.selectedTabID }) { tab in
                        Button(tab.displayTitle) { model.split(with: tab) }
                    }
                    if model.state.tabs.filter({ $0.spaceID == model.state.selectedSpaceID }).count < 2 {
                        Text("別のタブを開くと分割できます")
                    }
                } label: { Image(systemName: "rectangle.split.2x1") }
                    .menuStyle(.borderlessButton).fixedSize().help("別のタブと分割")
                    .disabled(model.selectedTab == nil).accessibilityIdentifier("split-toggle")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12).frame(height: 48)
        .overlay(alignment: .bottomLeading) {
            if let session = model.activeSession, session.isLoading {
                GeometryReader { proxy in
                    Rectangle().fill(model.tint).frame(width: proxy.size.width * session.estimatedProgress, height: 2)
                }.frame(height: 2)
            }
        }
    }

    private var displayAddress: String {
        guard let url = model.activeSession?.url, url.absoluteString != "about:blank" else { return "検索またはURLを入力" }
        return url.absoluteString.replacingOccurrences(of: "https://", with: "")
    }

    private var findBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("ページ内を検索", text: $model.findText)
                .accessibilityIdentifier("find-input")
                .focused($findFocused).onAppear { findFocused = true }
                .textFieldStyle(.plain).onSubmit { model.activeSession?.find(model.findText) }
                .onChange(of: model.findText) { _, value in model.activeSession?.find(value) }
            Button { model.activeSession?.find(model.findText, backwards: true) } label: { Image(systemName: "chevron.up") }
            Button { model.activeSession?.find(model.findText) } label: { Image(systemName: "chevron.down") }
            Button { model.showsFind = false } label: { Image(systemName: "xmark") }
        }.buttonStyle(.borderless).padding(10).background(.quaternary.opacity(0.4))
    }

    @ViewBuilder private var content: some View {
        if !model.visibleTabIDs.isEmpty {
            // Keep each tab's native host identity when adding/removing/reordering split panes.
            // Separate single/split branches can race to reparent the same WKWebView during teardown.
            GeometryReader { geometry in
                let ids = model.visibleTabIDs
                HStack(spacing: 0) {
                    ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                        if let tab = model.state.tabs.first(where: { $0.id == id }) {
                            BrowserPane(model: model, session: model.session(for: tab), tabID: tab.id)
                                .frame(width: paneWidth(index: index, count: ids.count, total: geometry.size.width))
                        }
                        if index == 0, ids.count == 2, let split = model.state.split {
                            Rectangle().fill(model.tint.opacity(0.3)).frame(width: 5)
                                .contentShape(Rectangle())
                                .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                                .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                                    if splitDragStart == nil { splitDragStart = split.fraction }
                                    model.store.send(.setSplitFraction((splitDragStart ?? 0.5) + value.translation.width / geometry.size.width))
                                }.onEnded { _ in splitDragStart = nil })
                                .accessibilityLabel("分割の幅")
                        }
                    }
                }
            }
        } else if let id = model.state.selectedFavoriteID, let favorite = model.state.favorites.first(where: { $0.id == id }) {
            BrowserPane(model: model, session: model.session(for: favorite), tabID: nil)
        } else { welcome }
    }

    private func paneWidth(index: Int, count: Int, total: CGFloat) -> CGFloat {
        guard count == 2 else { return max(0, total) }
        let fraction = model.state.split?.fraction ?? 0.5
        return max(0, total - 5) * (index == 0 ? fraction : 1 - fraction)
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 46, weight: .ultraLight)).foregroundStyle(model.tint)
            Text(model.selectedSpace?.name ?? "choco").font(.largeTitle.weight(.medium))
            Text("次のアイデアへ、ひとつのタブから。 ").foregroundStyle(.secondary)
            Button("検索またはURLを入力  ⌘T") { model.showCommand(.newTab) }.buttonStyle(.bordered)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BrowserPane: View {
    @Bindable var model: AppModel
    let session: WebSession
    let tabID: UUID?
    var body: some View {
        ZStack {
            if session.url == nil || session.url?.absoluteString == "about:blank" {
                VStack(spacing: 14) {
                    Image(systemName: "sparkle").font(.system(size: 40, weight: .light)).foregroundStyle(model.tint)
                    Text("新しいタブ").font(.title2.weight(.medium))
                    Button("検索またはURLを入力  ⌘L") { model.showCommand(.navigate) }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WebViewMount(webView: session.webView) { model.focusTab(tabID) }
            }
            if let message = session.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                    Text("ページを開けませんでした").font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("再試行") { session.reload() }.buttonStyle(.borderedProminent)
                }.padding(30).frame(maxWidth: 480)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.focusTab(tabID) })
        .overlay {
            if model.state.split != nil && model.focusedPaneID == tabID {
                Rectangle().strokeBorder(model.tint.opacity(0.45), lineWidth: 1).allowsHitTesting(false)
            }
        }
    }
}

private struct WebViewMount: NSViewRepresentable {
    let webView: WKWebView
    let onFocus: () -> Void
    func makeNSView(context: Context) -> WebViewContainer {
        let container = WebViewContainer()
        container.onFocus = onFocus
        attach(to: container)
        return container
    }
    func updateNSView(_ nsView: WebViewContainer, context: Context) { nsView.onFocus = onFocus; attach(to: nsView) }
    private func attach(to container: NSView) {
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

private struct WindowReference: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> WindowReferenceView {
        let view = WindowReferenceView()
        view.onWindow = onWindow
        return view
    }
    func updateNSView(_ nsView: WindowReferenceView, context: Context) { nsView.onWindow = onWindow }
}
private final class WindowReferenceView: NSView {
    var onWindow: ((NSWindow) -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onWindow?(window) }
    }
}

private final class WebViewContainer: NSView {
    var onFocus: (() -> Void)?
    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        if target != nil, NSApp.currentEvent?.type == .leftMouseDown { onFocus?() }
        return target
    }
}
