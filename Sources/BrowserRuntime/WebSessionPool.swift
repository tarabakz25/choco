import Foundation
import WebKit

@MainActor
public final class WebSessionPool {
    private var sessions: [UUID: WebSession] = [:]
    /// When set, every new session joins its profile's extension controller.
    public var extensions: ExtensionManager?
    public var onSessionAdded: ((WebSession) -> Void)?
    /// Called when a session is disposed. Releasing a session to another owner does not call it.
    public var onSessionRemoved: ((WebSession) -> Void)?
    /// One website data store object per profile. macOS 12 and later ignore extra
    /// WKProcessPool instances, so the pool is not duplicated here. Hibernation
    /// releases the web content process, which is the resident cost.
    private var dataStores = SharedObjectCache<WKWebsiteDataStore>()

    public init() {}

    public func existing(id: UUID) -> WebSession? { sessions[id] }

    public var residentIDs: Set<UUID> { Set(sessions.keys) }

    public func session(id: UUID, profileID: UUID, initialURL: URL? = nil, restoreScroll: PageScrollOffset? = nil) -> WebSession {
        if let existing = sessions[id], existing.profileID == profileID { return existing }
        remove(id: id)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore(for: profileID)
        let session = WebSession(id: id, profileID: profileID, configuration: configuration, extensionController: extensions?.controller(for: profileID))
        sessions[id] = session
        onSessionAdded?(session)
        if let initialURL {
            // Content scripts only reach pages loaded after the profile's extensions are in place.
            let begin: @MainActor () -> Void = { [weak session] in
                guard let session, session.webView.url == nil, !session.webView.isLoading else { return }
                session.navigate(to: initialURL, restoreScroll: restoreScroll)
            }
            if let extensions { extensions.whenReady(profileID: profileID, begin) } else { begin() }
        }
        return session
    }

    private func websiteDataStore(for profileID: UUID) -> WKWebsiteDataStore {
        // WebKit raises an Objective-C exception for the all-zero identifier.
        if profileID.uuidString == "00000000-0000-0000-0000-000000000000" { return .nonPersistent() }
        return dataStores.value(for: profileID) { WKWebsiteDataStore(forIdentifier: profileID) }
    }

    /// Popup navigation is performed by WebKit after its delegate receives this view.
    public func adopt(id: UUID, profileID: UUID, configuration: WKWebViewConfiguration) -> WebSession? {
        // A stale opener must never place its cookies in another profile's tab.
        // Alpha popup sessions use named persistent stores; private stores are
        // intentionally not accepted until private-window ownership is modeled.
        guard configuration.websiteDataStore.identifier == profileID else { return nil }
        remove(id: id)
        let session = WebSession(id: id, profileID: profileID, configuration: configuration)
        sessions[id] = session
        onSessionAdded?(session)
        return session
    }

    /// Hands the live session to a new owner (a detached window) without disposing it.
    public func release(id: UUID) -> WebSession? {
        sessions.removeValue(forKey: id)
    }

    public func remove(id: UUID) {
        guard let session = sessions.removeValue(forKey: id) else { return }
        onSessionRemoved?(session)
        session.dispose()
    }

    public func retainOnly(_ ids: Set<UUID>) {
        for id in Array(sessions.keys) where !ids.contains(id) { remove(id: id) }
    }
}
