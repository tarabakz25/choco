import Foundation
import WebKit

@MainActor
public final class WebSessionPool {
    private var sessions: [UUID: WebSession] = [:]
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
        let session = WebSession(id: id, profileID: profileID, initialURL: initialURL, restoreScroll: restoreScroll, configuration: configuration)
        sessions[id] = session
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
        return session
    }

    public func remove(id: UUID) {
        sessions.removeValue(forKey: id)?.dispose()
    }

    public func retainOnly(_ ids: Set<UUID>) {
        for id in Array(sessions.keys) where !ids.contains(id) { remove(id: id) }
    }
}
