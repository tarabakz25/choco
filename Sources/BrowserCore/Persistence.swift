import Foundation
import BrowserLocalization

struct LoadedState {
    var state: BrowserState
    var diagnostic: String?
    var canSave: Bool
}

enum StatePersistence {
    static let filename = "state.json"

    static func load(directory: URL) -> LoadedState {
        let file = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: file.path) else {
            return LoadedState(state: .initial(), diagnostic: nil, canSave: true)
        }
        do {
            let data = try Data(contentsOf: file)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any], let version = dictionary["schemaVersion"] as? Int else {
                throw LoadError.missingSchema
            }
            guard version == BrowserState.currentSchemaVersion else { throw LoadError.unsupportedSchema(version) }
            var state = try JSONDecoder().decode(BrowserState.self, from: data)
            let repairs = state.validateAndRepair()
            if !repairs.isEmpty {
                do {
                    let backup = try preserve(file: file, move: false)
                    return LoadedState(state: state, diagnostic: Localizer().format("Saved data was repaired. Original data: %@", backup.lastPathComponent), canSave: true)
                } catch {
                    return LoadedState(state: state, diagnostic: Localizer().format("Saved data references were repaired, but saving is paused because the original file could not be backed up. %@", error.localizedDescription), canSave: false)
                }
            }
            return LoadedState(state: state, diagnostic: nil, canSave: true)
        } catch {
            let cause = error.localizedDescription
            do {
                let backup = try preserve(file: file, move: true)
                return LoadedState(state: .initial(), diagnostic: Localizer().format("Started with a new state because saved data could not be loaded. %@ Original data: %@", cause, backup.lastPathComponent), canSave: true)
            } catch {
                return LoadedState(state: .initial(), diagnostic: Localizer().format("Saved data could not be loaded. Saving is paused to protect the original file. %@ Backup error: %@", cause, error.localizedDescription), canSave: false)
            }
        }
    }

    private static func preserve(file: URL, move: Bool) throws -> URL {
        let backup = file.deletingLastPathComponent().appendingPathComponent("state.recovery-\(UUID().uuidString).json")
        if move { try FileManager.default.moveItem(at: file, to: backup) }
        else { try FileManager.default.copyItem(at: file, to: backup) }
        return backup
    }

    enum LoadError: LocalizedError {
        case missingSchema, unsupportedSchema(Int)
        var errorDescription: String? {
            switch self {
            case .missingSchema: Localizer().text("The saved data has no format version.")
            case .unsupportedSchema(let version): Localizer().format("Saved data format version %lld is not supported.", version)
            }
        }
    }
}

/// One writer serializes disk access. Revisions also reject obsolete snapshots if
/// tasks reach this actor in a different order than they were created.
actor StateWriter {
    private let directory: URL
    private let canSave: Bool
    private var newestRevision: UInt64 = 0
    private var writtenRevision: UInt64?
    init(directory: URL, canSave: Bool) { self.directory = directory; self.canSave = canSave }

    func write(_ state: BrowserState, revision: UInt64) throws {
        guard canSave else { throw WriteError.recoveryRequired }
        guard revision >= newestRevision else { return }
        newestRevision = revision
        guard writtenRevision != revision else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(StatePersistence.filename), options: .atomic)
        writtenRevision = revision
    }

    enum WriteError: LocalizedError {
        case recoveryRequired
        var errorDescription: String? { Localizer().text("Saving is paused to protect the original saved data.") }
    }
}
