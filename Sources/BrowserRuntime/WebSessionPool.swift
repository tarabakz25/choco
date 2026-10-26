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

    public init() {}

    public func existingSession(id: UUID) -> WebSession? { sessions[id] }

    public func session(id: UUID, profileID: UUID, initialURL: URL? = nil) -> WebSession {
        if let existing = sessions[id], existing.profileID == profileID { return existing }
        remove(id: id)
        let session = WebSession(id: id, profileID: profileID, extensionController: extensions?.controller(for: profileID))
        sessions[id] = session
        onSessionAdded?(session)
        if let initialURL {
            // Content scripts only reach pages loaded after the profile's extensions are in place.
            let begin: @MainActor () -> Void = { [weak session] in
                guard let session, session.webView.url == nil, !session.webView.isLoading else { return }
                session.navigate(to: initialURL)
            }
            if let extensions { extensions.whenReady(profileID: profileID, begin) } else { begin() }
        }
        return session
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

    public func remove(id: UUID) {
        guard let session = sessions.removeValue(forKey: id) else { return }
        onSessionRemoved?(session)
        session.dispose()
    }

    public func retainOnly(_ ids: Set<UUID>) {
        for id in Array(sessions.keys) where !ids.contains(id) { remove(id: id) }
    }
}
