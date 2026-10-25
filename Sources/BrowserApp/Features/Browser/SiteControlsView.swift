import AppKit
import BrowserCore
import SwiftUI

/// Actions for the current page; unavailable extension/media features are not represented.
struct SiteControlsView: View {
    @Bindable var model: AppModel
    @ChocoReducedMotion private var reduceMotion: Bool
    @FocusState private var copyFocused: Bool
    @State private var hasAppeared = false
    @State private var copied = false

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
        VStack(alignment: .leading, spacing: 6) {
            quickActions
            sectionHeader("このページ")
            HStack(spacing: ChocoSpace.sm) {
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 28, height: 28)
                    SiteIcon(url: pageURL?.absoluteString ?? "", size: 16)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(pageURL == nil ? "ページが選択されていません" : pageTitle)
                        .font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                    Text(pageURL?.host ?? "URLを開くと操作できます")
                        .font(ChocoTheme.font(11)).foregroundStyle(ChocoTheme.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.frame(height: 40)
            sectionHeader("ページ操作")
            Button { togglePinned() } label: {
                settingsRow(title: currentTab?.isPinned == true ? "固定を解除" : "タブを固定",
                            subtitle: "現在のSpaceに保存") {
                    Image(systemName: currentTab?.isPinned == true ? "pin.slash" : "pin").font(.system(size: 14))
                }
            }.buttonStyle(SiteSettingsButtonStyle()).disabled(pageURL == nil)
                .accessibilityIdentifier("site-pin")
            Button { toggleFavorite() } label: {
                settingsRow(title: matchingFavorite == nil ? "お気に入りに追加" : "お気に入りを解除",
                            subtitle: matchingFavorite == nil && model.state.favorites.count >= 12 ? "登録できる上限は12件です" : "全Space共通のリンク") {
                    if matchingFavorite == nil { DesignIcon("77a3c", size: 15) }
                    else { Image(systemName: "star.fill").font(.system(size: 13)) }
                }
            }.buttonStyle(SiteSettingsButtonStyle()).disabled(!canToggleFavorite)
                .accessibilityIdentifier("site-favorite")
            Button {
                model.showsSiteControls = false
                model.showsFind = true
            } label: {
                settingsRow(title: "ページ内を検索", subtitle: "⌘F") { DesignIcon("9d9ff", size: 15) }
            }.buttonStyle(SiteSettingsButtonStyle()).disabled(pageURL == nil)
                .accessibilityIdentifier("site-find")
            splitAction
            footer
        }
        .padding(8).frame(width: 220)
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
        .task {
            hasAppeared = true
            await Task.yield()
            do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            guard model.showsSiteControls, !Task.isCancelled, pageURL != nil else { return }
            copyFocused = true
        }
    }

    private var quickActions: some View {
        HStack(spacing: ChocoSpace.sm) {
            if let pageURL {
                ShareLink(item: pageURL) {
                    quickTile { DesignIcon("d2996", size: 15) }
                }
                .buttonStyle(.plain).accessibilityLabel("ページを共有")
                .accessibilityIdentifier("site-share").help("ページを共有")
            } else {
                Button {} label: { quickTile { DesignIcon("d2996", size: 15) } }
                    .buttonStyle(.plain).disabled(true).accessibilityLabel("ページを共有")
            }
            Button { copyURL() } label: {
                quickTile {
                    if copied { Image(systemName: "checkmark").font(.system(size: 13)) }
                    else { DesignIcon("d4cd0", size: 15) }
                }
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(copyFocused ? .white.opacity(0.75) : .clear, lineWidth: 1))
            }
            .buttonStyle(.plain).focusable().focused($copyFocused).disabled(pageURL == nil)
            .accessibilityLabel(copied ? "URLをコピーしました" : "URLをコピー")
            .accessibilityIdentifier("site-copy-url").help("URLをコピー")
            Button { togglePinned() } label: {
                quickTile {
                    Image(systemName: currentTab?.isPinned == true ? "pin.fill" : "pin").font(.system(size: 13))
                }
            }.buttonStyle(.plain).disabled(pageURL == nil)
                .accessibilityLabel(currentTab?.isPinned == true ? "固定を解除" : "タブを固定")
                .accessibilityIdentifier("site-quick-pin").help(currentTab?.isPinned == true ? "固定を解除" : "タブを固定")
            Button { toggleFavorite() } label: {
                quickTile {
                    if matchingFavorite == nil { DesignIcon("77a3c", size: 15) }
                    else { Image(systemName: "star.fill").font(.system(size: 13)) }
                }
            }.buttonStyle(.plain).disabled(!canToggleFavorite)
                .accessibilityLabel(matchingFavorite == nil ? "お気に入りに追加" : "お気に入りを解除")
                .accessibilityIdentifier("site-quick-favorite").help("お気に入り")
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder private var splitAction: some View {
        if model.state.split != nil {
            Button {
                model.showsSiteControls = false
                model.send(.swapSplit)
            } label: {
                settingsRow(title: "分割を入れ替える", subtitle: "左右のページを交換") {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 14))
                }
            }.buttonStyle(SiteSettingsButtonStyle()).accessibilityIdentifier("split-swap")
            Button {
                model.showsSiteControls = false
                model.send(.clearSplit)
            } label: {
                settingsRow(title: "分割表示を解除", subtitle: "現在のタブを表示") {
                    Image(systemName: "rectangle").font(.system(size: 14))
                }
            }.buttonStyle(SiteSettingsButtonStyle()).accessibilityIdentifier("split-clear")
        } else {
            Menu {
                ForEach(splitCandidates) { tab in
                    Button(tab.displayTitle) {
                        model.showsSiteControls = false
                        model.split(with: tab)
                    }
                }
            } label: {
                settingsRow(title: "分割表示", subtitle: splitCandidates.isEmpty ? "別のタブを開くと利用できます" : "別のタブと並べる") {
                    Image(systemName: "rectangle.split.2x1").font(.system(size: 14))
                }
            }
            .menuStyle(.button).buttonStyle(SiteSettingsButtonStyle()).menuIndicator(.hidden)
            .tint(ChocoTheme.text).font(ChocoTheme.font(13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 40)
            .disabled(currentTab == nil || splitCandidates.isEmpty)
            .accessibilityIdentifier("split-toggle")
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                if pageURL?.scheme?.lowercased() == "https" { DesignIcon("dda43", size: 12).opacity(0.85) }
                else { Image(systemName: "globe").font(.system(size: 11)) }
                Text(pageURL.map { $0.scheme?.lowercased() == "https" ? "HTTPS接続" : "HTTP接続" } ?? "ページ未選択")
                    .font(ChocoTheme.font(11, weight: .semibold))
            }
            .padding(.leading, 8).padding(.trailing, 10).frame(height: 26)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .help("URLの接続方式です。サイトの信頼性を保証する表示ではありません。")
            .accessibilityIdentifier("site-connection")
            Spacer(minLength: 0)
            Menu {
                Button("URLを編集") { model.showCommand(.navigate) }.disabled(pageURL == nil)
                Button("再読み込み") { model.showsSiteControls = false; model.activeSession?.reload() }.disabled(pageURL == nil)
                Button("閉じる") { model.showsSiteControls = false }
            } label: {
                DesignIcon("a3077", size: 14).frame(width: 26, height: 26)
                    .background(.white.opacity(0.1), in: Circle())
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("その他のページ操作").accessibilityIdentifier("site-more")
        }.frame(height: 28)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(ChocoTheme.font(13, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 22)
    }

    /// Figma: four tiles share the 204pt content width equally (flex 1, 8pt gaps), so the row spans edge to edge.
    private func quickTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity).frame(height: 26)
            .background(Color(hex: "232323"), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    private func settingsRow<Icon: View>(title: String, subtitle: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: ChocoSpace.sm) {
            icon().frame(width: 28, height: 28).background(.white.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(ChocoTheme.font(11)).foregroundStyle(ChocoTheme.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 40)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private func copyURL() {
        guard let pageURL else { return }
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(pageURL.absoluteString, forType: .string)
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
        configuration.label
            .background(configuration.isPressed ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.45)
    }
}
