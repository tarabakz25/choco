import AppKit
import BrowserCore
import BrowserRuntime
import SwiftUI
import WebKit

/// Actions for the current page, plus the buttons of installed extensions.
struct SiteControlsView: View {
    @Bindable var model: AppModel
    @ChocoReducedMotion private var reduceMotion: Bool
    @State private var developerModeRefresh = false
    @State private var hasAppeared = false

    private var currentTab: BrowserTab? {
        guard let id = model.navigationTabID else { return nil }
        return model.state.tabs.first { $0.id == id }
    }
    private var pageURL: URL? {
        let favoriteAddress = model.state.favorites.first { $0.id == model.state.selectedFavoriteID }?.url
        guard let url = model.activeSession?.url ?? URL(string: currentTab?.url ?? favoriteAddress ?? ""),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
    private var pageTitle: String {
        currentTab?.displayTitle ?? model.activeSession?.title ?? pageURL?.host ?? "ページ"
    }
    private var matchingFavorite: BrowserFavorite? {
        guard let pageURL else { return nil }
        return model.state.favorites.first { $0.url == pageURL.absoluteString }
    }
    private var canToggleFavorite: Bool { pageURL != nil && (matchingFavorite != nil || model.state.favorites.count < 12) }
    private var splitCandidates: [BrowserTab] {
        guard let currentTab else { return [] }
        return model.state.tabs.filter { $0.spaceID == currentTab.spaceID && $0.id != currentTab.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ChocoSpace.u(6)) {
            quickActions
            storeInstallAction
            sectionHeader("拡張機能")
            extensionTiles
            sectionHeader("Boost")
            Button { UnsupportedNotice.shared.show("Boost") } label: {
                settingsRow(title: "新しいBoost", subtitle: "このサイトをカスタマイズ") { DesignIcon("aa001", size: 15) }
            }.buttonStyle(SiteSettingsButtonStyle()).accessibilityIdentifier("site-boost")
            sectionHeader("設定")
            Button { toggleDeveloperMode() } label: {
                settingsRow(title: "デベロッパーモード", subtitle: developerMode ? "オン" : "オフ") { DesignIcon("a6475", size: 15) }
            }.buttonStyle(SiteSettingsButtonStyle()).disabled(model.activeSession == nil)
                .accessibilityIdentifier("site-developer-mode")
            Button { UnsupportedNotice.shared.show("ピクチャインピクチャの自動表示") } label: {
                settingsRow(title: "自動ピクチャインピクチャ", subtitle: "許可") { DesignIcon("0c4d7", size: 15) }
            }.buttonStyle(SiteSettingsButtonStyle()).accessibilityIdentifier("site-auto-pip")
            footer
        }
        .padding(ChocoSpace.u(8)).frame(width: ChocoSpace.u(220))
        .foregroundStyle(ChocoTheme.text)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "767676").opacity(0.95)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 15, x: 0, y: 10)
        .opacity(reduceMotion || hasAppeared ? 1 : 0)
        .animation(reduceMotion ? nil : ChocoMotion.siteOpacity, value: hasAppeared)
        .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.95)
        .offset(x: reduceMotion || hasAppeared ? 0 : -5.5, y: reduceMotion || hasAppeared ? 0 : -15.15)
        .animation(reduceMotion ? nil : ChocoMotion.siteEntry, value: hasAppeared)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("site-controls")
        .onExitCommand { model.showsSiteControls = false }
        .task { hasAppeared = true }
    }

    private var developerMode: Bool { _ = developerModeRefresh; return model.activeSession?.webView.isInspectable ?? false }

    private func toggleDeveloperMode() {
        guard let webView = model.activeSession?.webView else { return }
        webView.isInspectable.toggle()
        developerModeRefresh.toggle()
    }

    /// Figma "quick actions": share, Boost, page capture, area capture — four equal 26pt tiles.
    private var quickActions: some View {
        HStack(spacing: ChocoSpace.u(8)) {
            if let pageURL {
                ShareLink(item: pageURL) { quickTile { DesignIcon("d2996", size: 15) } }
                    .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1))).accessibilityLabel("ページを共有")
                    .accessibilityIdentifier("site-share").help("ページを共有")
            } else {
                Button {} label: { quickTile { DesignIcon("d2996", size: 15) } }
                    .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1))).disabled(true).accessibilityLabel("ページを共有")
            }
            Button { UnsupportedNotice.shared.show("Boost") } label: { quickTile { DesignIcon("aa001", size: 15) } }
                .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1)))
                .accessibilityLabel("Boost").accessibilityIdentifier("site-quick-boost").help("Boost")
            Button { savePageScreenshot() } label: { quickTile { DesignIcon("89a0b", size: 15) } }
                .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1))).disabled(model.activeSession == nil)
                .accessibilityLabel("ページのスクリーンショット").accessibilityIdentifier("site-screenshot").help("ページのスクリーンショット")
            Button { UnsupportedNotice.shared.show("範囲のキャプチャ") } label: { quickTile { DesignIcon("5d0e2", size: 15) } }
                .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1)))
                .accessibilityLabel("範囲をキャプチャ").accessibilityIdentifier("site-capture").help("範囲をキャプチャ")
        }.frame(maxWidth: .infinity)
    }

    private func savePageScreenshot() {
        guard let webView = model.activeSession?.webView else { return }
        let name = (pageURL?.host ?? "page") + ".png"
        model.showsSiteControls = false
        webView.takeSnapshot(with: nil) { image, _ in
            guard let image, let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            Task { @MainActor in
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = name
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try? png.write(to: url)
            }
        }
    }

    /// Figma "extensions": installed extensions then a "+" tile, 8pt apart in rows of four.
    private var extensionTiles: some View {
        let profileID = model.activeSession?.profileID ?? model.selectedSpace?.profileID
        let entries = profileID.map { model.extensions.loadedContexts(profileID: $0) } ?? []
        let tab = profileID.flatMap { model.extensionHost.activeTab(profileID: $0) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ChocoSpace.u(8)), count: 4), spacing: ChocoSpace.u(8)) {
            ForEach(entries, id: \.item.id) { entry in
                let action = entry.context.action(for: tab)
                Button {
                    model.showsSiteControls = false
                    model.extensionHost.perform(entry.context)
                } label: {
                    extensionTile {
                        if let icon = action?.icon(for: CGSize(width: 32, height: 32)) {
                            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: ChocoSpace.u(16), height: ChocoSpace.u(16))
                        } else {
                            Image(systemName: "puzzlepiece.extension").font(.system(size: ChocoSpace.u(13)))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let badge = action?.badgeText, !badge.isEmpty {
                            Text(badge).font(ChocoTheme.font(9, weight: .bold)).lineLimit(1)
                                .padding(.horizontal, 3).background(model.tint, in: Capsule()).offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1)))
                .disabled(action?.isEnabled == false)
                .help(action?.label.isEmpty == false ? action?.label ?? entry.item.name : entry.item.name)
                .accessibilityLabel(entry.item.name)
                .accessibilityIdentifier("extension-action-\(entry.item.id)")
            }
            Button {
                model.showsSiteControls = false
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: { extensionTile { DesignIcon("77a3c", size: 13).opacity(0.8) } }
                .buttonStyle(ChocoPressStyle(radius: 7, tint: .white.opacity(0.2), hoverTint: .white.opacity(0.1)))
                .accessibilityLabel("拡張機能を追加").accessibilityIdentifier("site-add-extension").help("拡張機能を追加")
        }
    }

    /// Shown on a Chrome Web Store page, where the store's own "Add to Chrome" button is disabled outside Chrome.
    @ViewBuilder private var storeInstallAction: some View {
        if let pageURL, let storeID = ChromeWebStore.storeDetailID(of: pageURL) {
            let installed = model.extensions.installed.contains { $0.storeID == storeID }
            Button {
                model.showsSiteControls = false
                Task { await model.extensionHost.installFromStore(pageURL.absoluteString) }
            } label: {
                settingsRow(title: installed ? "この拡張機能を更新" : "この拡張機能を追加",
                            subtitle: installed ? "ストアの最新版に置き換え" : "Chromeウェブストアから入手") {
                    Image(systemName: installed ? "arrow.triangle.2.circlepath" : "plus").font(.system(size: ChocoSpace.u(13)))
                }
            }.buttonStyle(SiteSettingsButtonStyle()).accessibilityIdentifier("site-install-extension")
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: ChocoSpace.u(5)) {
                if pageURL?.scheme?.lowercased() == "https" { DesignIcon("dda43", size: 12).opacity(0.85) }
                else { Image(systemName: "globe").font(.system(size: ChocoSpace.u(11))) }
                Text(pageURL.map { $0.scheme?.lowercased() == "https" ? "HTTPS接続" : "HTTP接続" } ?? "ページ未選択")
                    .font(ChocoTheme.font(11, weight: .semibold))
            }
            .padding(.leading, ChocoSpace.u(8)).padding(.trailing, ChocoSpace.u(10)).frame(height: ChocoSpace.u(26))
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .help("URLの接続方式です。サイトの信頼性を保証する表示ではありません。")
            .accessibilityIdentifier("site-connection")
            Spacer(minLength: 0)
            Menu {
                Button("URLをコピー") { copyURL() }.disabled(pageURL == nil)
                Button(currentTab?.isPinned == true ? "固定を解除" : "タブを固定") { togglePinned() }.disabled(pageURL == nil)
                Button(matchingFavorite == nil ? "お気に入りに追加" : "お気に入りを解除") { toggleFavorite() }.disabled(!canToggleFavorite)
                Button("ページ内を検索") { model.showsSiteControls = false; model.showsFind = true }.disabled(pageURL == nil)
                Divider()
                if model.state.split != nil {
                    Button("分割を入れ替える") { model.showsSiteControls = false; model.send(.swapSplit) }
                    Button("分割表示を解除") { model.showsSiteControls = false; model.send(.clearSplit) }
                } else {
                    Menu("分割表示") {
                        ForEach(splitCandidates) { tab in
                            Button(tab.displayTitle) { model.showsSiteControls = false; model.split(with: tab) }
                        }
                    }.disabled(currentTab == nil || splitCandidates.isEmpty)
                }
                Divider()
                Button("URLを編集") { model.showCommand(.navigate) }.disabled(pageURL == nil)
                Button("再読み込み") { model.showsSiteControls = false; model.activeSession?.reload() }.disabled(pageURL == nil)
                Button("閉じる") { model.showsSiteControls = false }
            } label: {
                DesignIcon("a3077", size: 14).frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
                    .background(.white.opacity(0.1), in: Circle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("その他のページ操作").accessibilityIdentifier("site-more")
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        }.frame(height: ChocoSpace.u(28))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(ChocoTheme.font(13, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: ChocoSpace.u(22))
    }

    /// Figma: four tiles share the 204pt content width equally (flex 1, 8pt gaps), so the row spans edge to edge.
    private func quickTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity).frame(height: ChocoSpace.u(26))
            .background(Color(hex: "232323"), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    private func extensionTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity).frame(height: ChocoSpace.u(26))
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    private func settingsRow<Icon: View>(title: String, subtitle: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: ChocoSpace.sm) {
            icon().frame(width: ChocoSpace.u(28), height: ChocoSpace.u(28)).background(.white.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(ChocoTheme.font(11)).foregroundStyle(ChocoTheme.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading).frame(height: ChocoSpace.u(40))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private func copyURL() {
        guard let pageURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pageURL.absoluteString, forType: .string)
    }

    private func togglePinned() {
        guard let pageURL else { return }
        if let currentTab {
            model.send(currentTab.isPinned ? .unpinTab(currentTab.id) : .pinTab(currentTab.id))
        } else {
            model.send(.newTab(url: pageURL.absoluteString))
            if let id = model.state.selectedTabID { model.send(.pinTab(id)) }
        }
        model.showsSiteControls = false
    }

    private func toggleFavorite() {
        guard let pageURL, canToggleFavorite else { return }
        if let matchingFavorite { model.send(.deleteFavorite(matchingFavorite.id)) }
        else { model.send(.createFavorite(title: pageTitle, url: pageURL.absoluteString)) }
        model.showsSiteControls = false
    }
}

private struct SiteSettingsButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        ChocoPressStyle(radius: 8, tint: .white.opacity(0.12), hoverTint: .white.opacity(0.06))
            .makeBody(configuration: configuration)
            .opacity(isEnabled ? 1 : 0.45)
    }
}
