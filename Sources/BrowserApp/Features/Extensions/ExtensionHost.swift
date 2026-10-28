import AppKit
import BrowserCore
import BrowserRuntime
import WebKit

/// Connects extensions to the browser: answers their questions about windows and tabs,
/// forwards tab events, and presents popups, options pages and permission prompts.
@MainActor final class ExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    weak var model: AppModel?
    private let manager: ExtensionManager
    private var tabsByID: [UUID: ExtensionTab] = [:]
    private var windowsByProfile: [UUID: ExtensionWindow] = [:]
    private var lastActiveByProfile: [UUID: UUID] = [:]
    private var activeSessionID: UUID?
    private var pageWindows: [ExtensionPageWindow] = []

    init(manager: ExtensionManager) {
        self.manager = manager
        super.init()
    }

    // MARK: Tabs and windows

    func window(for profileID: UUID) -> ExtensionWindow {
        if let existing = windowsByProfile[profileID] { return existing }
        let window = ExtensionWindow(profileID: profileID, host: self)
        windowsByProfile[profileID] = window
        return window
    }

    var presentationWindow: NSWindow? {
        if let key = NSApp.keyWindow, key.contentView != nil, !(key is NSPanel) { return key }
        return model?.browserWindow
    }

    func record(for id: UUID) -> BrowserTab? { model?.state.tabs.first { $0.id == id } }

    private func profileID(of record: BrowserTab) -> UUID? {
        model?.state.spaces.first { $0.id == record.spaceID }?.profileID
    }

    /// Every Core tab of the profile, whether or not its page has been created, then any session that is not a Core tab (favorites).
    func tabs(profileID: UUID) -> [ExtensionTab] {
        guard let model else { return [] }
        var result: [ExtensionTab] = []
        for record in model.state.tabs where self.profileID(of: record) == profileID {
            if let existing = tabsByID[record.id], existing.profileID == profileID { result.append(existing); continue }
            let tab = ExtensionTab(id: record.id, profileID: profileID, session: nil, host: self)
            tabsByID[record.id] = tab
            result.append(tab)
        }
        let recordIDs = Set(model.state.tabs.map(\.id))
        result += tabsByID.values.filter { !recordIDs.contains($0.id) && $0.profileID == profileID && $0.session != nil }
        return result
    }

    func activeTab(profileID: UUID) -> ExtensionTab? {
        if let current = activeSessionID, let tab = tabsByID[current], tab.profileID == profileID { return tab }
        return lastActiveByProfile[profileID].flatMap { tabsByID[$0] }
    }

    func index(of tab: ExtensionTab) -> Int { tabs(profileID: tab.profileID).firstIndex { $0 === tab } ?? 0 }
    func isActive(_ tab: ExtensionTab) -> Bool { activeSessionID == tab.id }

    func activate(_ id: UUID) {
        guard let model, let tab = record(for: id) else { return }
        model.select(tab)
    }

    func close(_ id: UUID) {
        guard let model, record(for: id) != nil else { return }
        model.send(.closeTab(id))
    }

    /// Creates the page for a tab that has none yet.
    func mountSession(for id: UUID) -> WebSession? {
        guard let model, let record = record(for: id) else { return nil }
        return model.session(for: record)
    }

    // MARK: Events from the browser

    func sessionAdded(_ session: WebSession) {
        let tab: ExtensionTab
        if let existing = tabsByID[session.id], existing.profileID == session.profileID {
            tab = existing
            tab.attach(session)
        } else {
            tab = ExtensionTab(id: session.id, profileID: session.profileID, session: session, host: self)
            tabsByID[session.id] = tab
        }
        session.onStateChange = { [weak self] session in self?.stateChanged(session) }
        if !tab.isAnnounced {
            tab.isAnnounced = true
            manager.controller(for: session.profileID).didOpenTab(tab)
        }
    }

    func sessionRemoved(_ session: WebSession) {
        guard let tab = tabsByID[session.id], tab.session === session else { return }
        if lastActiveByProfile[session.profileID] == session.id { lastActiveByProfile[session.profileID] = nil }
        if activeSessionID == session.id { activeSessionID = nil }
        // Hibernating a tab drops its page but not the tab. Closing it, or moving it to another profile, ends this tab.
        if let record = record(for: session.id), profileID(of: record) == session.profileID {
            tab.detach()
            return
        }
        tabsByID[session.id] = nil
        if tab.isAnnounced { manager.controller(for: session.profileID).didCloseTab(tab, windowIsClosing: false) }
    }

    /// Forgets tabs that were closed without ever having a page (a page's own removal is handled by `sessionRemoved`).
    func pruneClosedTabs() {
        guard let model else { return }
        let recordIDs = Set(model.state.tabs.map(\.id))
        for (id, tab) in tabsByID where tab.session == nil && !recordIDs.contains(id) {
            tabsByID[id] = nil
            if tab.isAnnounced { manager.controller(for: tab.profileID).didCloseTab(tab, windowIsClosing: false) }
        }
    }

    private func stateChanged(_ session: WebSession) {
        guard let tab = tabsByID[session.id] else { return }
        let changed = tab.takeChangedProperties()
        if !changed.isEmpty { manager.controller(for: session.profileID).didChangeTabProperties(changed, for: tab) }
    }

    /// Call after anything that can change which page is in front.
    func activeTabMayHaveChanged(to session: WebSession?) {
        guard session?.id != activeSessionID else { return }
        let previous = activeSessionID.flatMap { tabsByID[$0] }
        activeSessionID = session?.id
        guard let session, let tab = tabsByID[session.id] else { return }
        lastActiveByProfile[session.profileID] = session.id
        let controller = manager.controller(for: session.profileID)
        let sameProfilePrevious = previous?.profileID == session.profileID ? previous : nil
        controller.didActivateTab(tab, previousActiveTab: sameProfilePrevious)
        controller.didSelectTabs([tab])
        if let sameProfilePrevious { controller.didDeselectTabs([sameProfilePrevious]) }
    }

    /// Opens the extension's popup, or its click handler when it has none.
    func perform(_ context: WKWebExtensionContext) {
        guard let profileID = context.webExtensionController?.configuration.identifier else { return }
        context.performAction(for: activeTab(profileID: profileID))
    }

    // MARK: Installing from the Chrome Web Store

    private var isInstalling = false

    /// Asks the user to approve what the extension requests. Used by Settings and by the Web Store page button.
    func confirmInstall(_ staged: StagedExtension) -> Bool {
        let alert = NSAlert()
        alert.messageText = "「\(staged.name)」を追加しますか？"
        var lines: [String] = []
        if !staged.version.isEmpty { lines.append("バージョン \(staged.version)") }
        if staged.permissions.isEmpty && staged.sitePatterns.isEmpty { lines.append("特別な権限は要求されません。") }
        if !staged.permissions.isEmpty { lines.append("要求する権限: " + staged.permissions.joined(separator: "、")) }
        if !staged.sitePatterns.isEmpty {
            let shown = staged.sitePatterns.prefix(8).joined(separator: "、")
            let rest = staged.sitePatterns.count > 8 ? " ほか\(staged.sitePatterns.count - 8)件" : ""
            lines.append(staged.sitePatterns.contains { $0 == "<all_urls>" || $0.hasPrefix("*://*/") }
                ? "すべてのサイトのデータを読み取り・変更できます。"
                : "アクセスするサイト: \(shown)\(rest)")
        }
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "キャンセル")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Installs the extension of a Web Store page. The store's own "Add to Chrome" button only works in Chrome,
    /// so this is the in-app replacement; results are reported in an alert because the caller's UI is already gone.
    func installFromStore(_ reference: String) async {
        guard !isInstalling else { return }
        isInstalling = true
        defer { isInstalling = false }
        let result = NSAlert()
        do {
            let staged = try await manager.stage(storeReference: reference)
            guard confirmInstall(staged) else { manager.discard(staged); return }
            let item = try await manager.commit(staged)
            if let error = manager.loadErrors[item.id] {
                result.messageText = "「\(item.name)」を追加しましたが、読み込めませんでした。"
                result.informativeText = error
                result.alertStyle = .warning
            } else {
                result.messageText = "「\(item.name)」を追加しました。"
                result.informativeText = "拡張機能のボタンは、サイトの操作パネルに表示されます。"
            }
        } catch {
            result.messageText = "拡張機能を追加できませんでした。"
            result.informativeText = error.localizedDescription
            result.alertStyle = .warning
        }
        result.addButton(withTitle: "OK")
        result.runModal()
    }

    // MARK: WKWebExtensionControllerDelegate

    private func profileID(of controller: WKWebExtensionController) -> UUID? {
        controller.configuration.identifier ?? model?.selectedSpace?.profileID
    }

    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        profileID(of: controller).map { [window(for: $0)] } ?? []
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        profileID(of: controller).map { window(for: $0) }
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                for extensionContext: WKWebExtensionContext) async throws -> (any WKWebExtensionTab)? {
        let url = configuration.url
        if let url, !["http", "https", "about"].contains(url.scheme?.lowercased() ?? "") {
            // Extension pages need the extension's own web view configuration, so they get their own window.
            guard let tab = openPage(url, in: extensionContext) else { throw ExtensionHostError.cannotOpen }
            return tab
        }
        guard let model, let profileID = profileID(of: controller),
              let space = model.space(preferring: profileID) else { throw ExtensionHostError.cannotOpen }
        let previousTabID = model.state.selectedTabID
        let previousSpaceID = model.state.selectedSpaceID
        let previousFavoriteID = model.state.selectedFavoriteID
        let id = UUID()
        model.send(.newTabWithID(id: id, spaceID: space.id, url: url?.absoluteString ?? "about:blank"))
        guard let created = model.state.tabs.first(where: { $0.id == id }) else { throw ExtensionHostError.cannotOpen }
        _ = model.session(for: created)
        if !configuration.shouldBeActive, previousTabID != nil || previousFavoriteID != nil {
            if previousSpaceID != space.id { model.send(.selectSpace(previousSpaceID)) }
            // A displayed favorite has no selected tab, and selecting a tab would replace it.
            if let previousTabID { model.send(.selectTab(previousTabID)) }
            if let previousFavoriteID { model.send(.selectFavorite(previousFavoriteID)) }
        }
        return tabsByID[id]
    }

    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext) async throws {
        guard let url = extensionContext.optionsPageURL, openPage(url, in: extensionContext) != nil else { throw ExtensionHostError.cannotOpen }
    }

    private func openPage(_ url: URL, in context: WKWebExtensionContext) -> ExtensionPageTab? {
        guard let page = ExtensionPageWindow(context: context, url: url, onClose: { [weak self] page in
            self?.pageWindows.removeAll { $0 === page }
        }) else { return nil }
        pageWindows.append(page)
        return ExtensionPageTab(webView: page.webView, window: page)
    }

    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action,
                                for extensionContext: WKWebExtensionContext) async throws {
        guard let popover = action.popupPopover, let window = presentationWindow, let view = window.contentView else {
            throw ExtensionHostError.cannotOpen
        }
        // The popup opens where the pointer is, which is where the extension's button was clicked.
        let point = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let anchor = NSRect(x: min(max(point.x, 0), view.bounds.maxX), y: min(max(point.y, 0), view.bounds.maxY), width: 1, height: 1)
        popover.behavior = .transient
        popover.show(relativeTo: anchor, of: view, preferredEdge: view.isFlipped ? .maxY : .minY)
    }

    func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action,
                                forExtensionContext context: WKWebExtensionContext) {
        manager.noteChange()
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.Permission>, Date?) {
        let names = permissions.map(\.rawValue).sorted().joined(separator: "、")
        return (confirm(extensionContext, detail: "次の権限を要求しています: \(names)") ? permissions : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<URL>, Date?) {
        let names = urls.compactMap(\.host).sorted().joined(separator: "、")
        return (confirm(extensionContext, detail: "次のサイトのデータへのアクセスを要求しています: \(names)") ? urls : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.MatchPattern>, Date?) {
        let names = matchPatterns.map(\.string).sorted().joined(separator: "、")
        return (confirm(extensionContext, detail: "次のサイトのデータへのアクセスを要求しています: \(names)") ? matchPatterns : [], nil)
    }

    private func confirm(_ context: WKWebExtensionContext, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "「\(context.webExtension.displayName ?? "拡張機能")」が追加の許可を求めています"
        alert.informativeText = detail
        alert.addButton(withTitle: "許可")
        alert.addButton(withTitle: "許可しない")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

enum ExtensionHostError: LocalizedError {
    case cannotOpen
    var errorDescription: String? { "このブラウザでは開けません。" }
}
