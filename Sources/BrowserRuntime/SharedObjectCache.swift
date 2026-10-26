import Foundation

/// Reuses one class instance per identifier. The session pool uses this so every
/// tab in a profile holds the same WKWebsiteDataStore object.
struct SharedObjectCache<Value: AnyObject> {
    private var storage: [UUID: Value] = [:]

    mutating func value(for id: UUID, make: () -> Value) -> Value {
        if let existing = storage[id] { return existing }
        let created = make()
        storage[id] = created
        return created
    }

    mutating func remove(_ id: UUID) {
        storage[id] = nil
    }
}
