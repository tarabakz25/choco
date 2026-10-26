import Foundation
import WebKit

@MainActor
public final class WebSessionPool {
    private var sessions: [UUID: WebSession] = [:]

    public init() {}

    public func session(id: UUID, profileID: UUID, initialURL: URL? = nil) -> WebSession {
        if let existing = sessions[id], existing.profileID == profileID { return existing }
        remove(id: id)
        let session = WebSession(id: id, profileID: profileID, initialURL: initialURL)
        sessions[id] = session
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
        return session
    }

    /// Hands the live session to a new owner (a detached window) without disposing it.
    public func release(id: UUID) -> WebSession? {
        sessions.removeValue(forKey: id)
    }

    public func remove(id: UUID) {
        sessions.removeValue(forKey: id)?.dispose()
    }

    public func retainOnly(_ ids: Set<UUID>) {
        for id in Array(sessions.keys) where !ids.contains(id) { remove(id: id) }
    }
}
