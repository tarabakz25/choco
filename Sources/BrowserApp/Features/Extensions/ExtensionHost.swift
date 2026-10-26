import AppKit
import BrowserCore
import BrowserRuntime
import WebKit

/// Connects extensions to the browser: answers their questions about windows and tabs,
/// forwards tab events, and presents popups, options pages and permission prompts.
@MainActor final class ExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    weak var model: AppModel?
    private let manager: ExtensionManager
    private var tabsBySession: [UUID: ExtensionTab] = [:]
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

    func tabs(profileID: UUID) -> [ExtensionTab] {
        let order = model?.state.tabs.map(\.id) ?? []
        return tabsBySession.values.filter { $0.session.profileID == profileID }.sorted {
            (order.firstIndex(of: $0.session.id) ?? .max) < (order.firstIndex(of: $1.session.id) ?? .max)
        }
    }

    func activeTab(profileID: UUID) -> ExtensionTab? {
        if let current = activeSessionID, let tab = tabsBySession[current], tab.session.profileID == profileID { return tab }
        return lastActiveByProfile[profileID].flatMap { tabsBySession[$0] }
    }

    func index(of tab: ExtensionTab) -> Int { tabs(profileID: tab.session.profileID).firstIndex { $0 === tab } ?? 0 }
    func isActive(_ tab: ExtensionTab) -> Bool { activeSessionID == tab.session.id }
    func isPinned(_ session: WebSession) -> Bool { model?.state.tabs.first { $0.id == session.id }?.isPinned ?? false }

    func activate(_ session: WebSession) {
        guard let model, let tab = model.state.tabs.first(where: { $0.id == session.id }) else { return }
        model.select(tab)
    }

    func close(_ session: WebSession) {
        guard let model, model.state.tabs.contains(where: { $0.id == session.id }) else { return }
        model.send(.closeTab(session.id))
    }

    // MARK: Events from the browser

    func sessionAdded(_ session: WebSession) {
        let tab = ExtensionTab(session: session, host: self)
        tabsBySession[session.id] = tab
        session.onStateChange = { [weak self] session in self?.stateChanged(session) }
        manager.controller(for: session.profileID).didOpenTab(tab)
    }

    func sessionRemoved(_ session: WebSession) {
        guard let tab = tabsBySession.removeValue(forKey: session.id) else { return }
        if lastActiveByProfile[session.profileID] == session.id { lastActiveByProfile[session.profileID] = nil }
        if activeSessionID == session.id { activeSessionID = nil }
        manager.controller(for: session.profileID).didCloseTab(tab, windowIsClosing: false)
    }

    private func stateChanged(_ session: WebSession) {
        guard let tab = tabsBySession[session.id] else { return }
        let changed = tab.takeChangedProperties()
        if !changed.isEmpty { manager.controller(for: session.profileID).didChangeTabProperties(changed, for: tab) }
    }

    /// Call after anything that can change which page is in front.
    func activeTabMayHaveChanged(to session: WebSession?) {
        guard session?.id != activeSessionID else { return }
        let previous = activeSessionID.flatMap { tabsBySession[$0] }
        activeSessionID = session?.id
        guard let session, let tab = tabsBySession[session.id] else { return }
        lastActiveByProfile[session.profileID] = session.id
        let controller = manager.controller(for: session.profileID)
        let sameProfilePrevious = previous?.session.profileID == session.profileID ? previous : nil
        controller.didActivateTab(tab, previousActiveTab: sameProfilePrevious)
        controller.didSelectTabs([tab])
        if let sameProfilePrevious { controller.didDeselectTabs([sameProfilePrevious]) }
    }

    /// Opens the extension's popup, or its click handler when it has none.
    func perform(_ context: WKWebExtensionContext) {
        guard let profileID = context.webExtensionController?.configuration.identifier else { return }
        context.performAction(for: activeTab(profileID: profileID))
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
        let id = UUID()
        model.send(.newTabWithID(id: id, spaceID: space.id, url: url?.absoluteString ?? "about:blank"))
        guard let created = model.state.tabs.first(where: { $0.id == id }) else { throw ExtensionHostError.cannotOpen }
        _ = model.session(for: created)
        if !configuration.shouldBeActive, let previousTabID {
            if previousSpaceID != space.id { model.send(.selectSpace(previousSpaceID)) }
            model.send(.selectTab(previousTabID))
        }
        return tabsBySession[id]
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

private enum ExtensionHostError: LocalizedError {
    case cannotOpen
    var errorDescription: String? { "このブラウザでは開けません。" }
}
