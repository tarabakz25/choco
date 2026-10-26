import Foundation
import Observation
import WebKit

public struct InstalledExtension: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var isEnabled: Bool
    /// Chrome Web Store ID, when installed from the store; re-installing the same ID updates in place.
    public var storeID: String?
    /// A folder or `.zip` inside the manager's `Packages` directory.
    var packageName: String
}

/// An extension that has been unpacked and validated but not yet installed.
/// The app shows `permissions` and `sitePatterns` for consent before calling `commit`.
public struct StagedExtension: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let permissions: [String]
    public let sitePatterns: [String]
    let storeID: String?
    let stagingDirectory: URL
    let packageName: String
}

/// Installs Chrome-style extensions and runs them in one `WKWebExtensionController` per profile.
/// A profile's controller shares that profile's website data store, so extensions see the same cookies as its tabs.
@MainActor @Observable
public final class ExtensionManager {
    public private(set) var installed: [InstalledExtension]
    /// Why an enabled extension failed to load, keyed by extension ID.
    public private(set) var loadErrors: [String: String] = [:]
    /// Bumped whenever the loaded contexts or their actions change, so views can refresh.
    public private(set) var revision = 0
    @ObservationIgnored public weak var delegate: (any WKWebExtensionControllerDelegate)?

    @ObservationIgnored private let root: URL
    @ObservationIgnored private var controllers: [UUID: WKWebExtensionController] = [:]
    @ObservationIgnored private var contexts: [UUID: [String: WKWebExtensionContext]] = [:]
    @ObservationIgnored private var readyProfiles: Set<UUID> = []
    @ObservationIgnored private var waiters: [UUID: [@MainActor () -> Void]] = [:]
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    public init(directory: URL) {
        root = directory
        installed = Self.loadCatalog(in: directory)
    }

    private var packagesDirectory: URL { root.appendingPathComponent("Packages", isDirectory: true) }
    private var stagingRoot: URL { root.appendingPathComponent("Staging", isDirectory: true) }
    private var catalogURL: URL { root.appendingPathComponent("extensions.json") }

    // MARK: Controllers

    /// The controller to give a profile's web views. Extensions load shortly after it is first created.
    public func controller(for profileID: UUID) -> WKWebExtensionController {
        if let existing = controllers[profileID] { return existing }
        let configuration: WKWebExtensionController.Configuration
        if profileID.uuidString == "00000000-0000-0000-0000-000000000000" {
            configuration = .nonPersistent()
        } else {
            configuration = .init(identifier: profileID)
            configuration.defaultWebsiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        }
        let controller = WKWebExtensionController(configuration: configuration)
        controller.delegate = delegate
        controllers[profileID] = controller
        if installed.contains(where: \.isEnabled) { scheduleSync() } else { readyProfiles.insert(profileID) }
        return controller
    }

    /// Runs `work` once this profile's enabled extensions are loaded, so content scripts reach the first navigation.
    public func whenReady(profileID: UUID, _ work: @escaping @MainActor () -> Void) {
        if readyProfiles.contains(profileID) { work() } else { waiters[profileID, default: []].append(work) }
    }

    public func loadedContexts(profileID: UUID) -> [(item: InstalledExtension, context: WKWebExtensionContext)] {
        _ = revision
        guard let loaded = contexts[profileID] else { return [] }
        return installed.compactMap { item in loaded[item.id].map { (item, $0) } }
    }

    /// The loaded context for an extension-scheme URL, if any extension owns it.
    public func context(for url: URL, profileID: UUID) -> WKWebExtensionContext? {
        controllers[profileID]?.extensionContext(for: url)
    }

    public func noteChange() { revision &+= 1 }

    // MARK: Installing

    public func stage(fileURL: URL) async throws -> StagedExtension {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else { throw ExtensionError.invalidSource }
        let directory = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            if isDirectory.boolValue {
                guard FileManager.default.fileExists(atPath: fileURL.appendingPathComponent("manifest.json").path) else {
                    throw ExtensionError.invalid("選んだフォルダの直下にmanifest.jsonがありません。")
                }
                let package = directory.appendingPathComponent("package", isDirectory: true)
                try FileManager.default.copyItem(at: fileURL, to: package)
                return try await finishStaging(directory: directory, packageName: "package", storeID: nil)
            }
            let zip = try ChromeWebStore.zipPayload(of: Data(contentsOf: fileURL))
            try zip.write(to: directory.appendingPathComponent("package.zip"))
            return try await finishStaging(directory: directory, packageName: "package.zip", storeID: nil)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    /// Downloads a Chrome Web Store extension by listing URL or ID. The CRX signature is not verified.
    public func stage(storeReference: String) async throws -> StagedExtension {
        guard let id = ChromeWebStore.extensionID(from: storeReference), let url = ChromeWebStore.downloadURL(for: id) else {
            throw ExtensionError.invalidSource
        }
        let data: Data
        do {
            let (body, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, !body.isEmpty else {
                throw ExtensionError.download("ストアに該当する拡張機能が見つかりません。")
            }
            data = body
        } catch let error as ExtensionError { throw error } catch { throw ExtensionError.download(error.localizedDescription) }
        let directory = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try ChromeWebStore.zipPayload(of: data).write(to: directory.appendingPathComponent("package.zip"))
            return try await finishStaging(directory: directory, packageName: "package.zip", storeID: id)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private func finishStaging(directory: URL, packageName: String, storeID: String?) async throws -> StagedExtension {
        let extensionObject: WKWebExtension
        do { extensionObject = try await WKWebExtension(resourceBaseURL: directory.appendingPathComponent(packageName)) }
        catch { throw ExtensionError.invalid(error.localizedDescription) }
        let name = extensionObject.displayName ?? extensionObject.displayShortName ?? "名称なし"
        return StagedExtension(
            id: UUID().uuidString, name: name, version: extensionObject.displayVersion ?? extensionObject.version ?? "",
            permissions: extensionObject.requestedPermissions.map(\.rawValue).sorted(),
            sitePatterns: extensionObject.allRequestedMatchPatterns.map(\.string).sorted(),
            storeID: storeID, stagingDirectory: directory, packageName: packageName
        )
    }

    public func discard(_ staged: StagedExtension) {
        try? FileManager.default.removeItem(at: staged.stagingDirectory)
    }

    /// Installs a staged extension and enables it in every profile. Reinstalling a store ID replaces the old copy but keeps its data.
    @discardableResult
    public func commit(_ staged: StagedExtension) async throws -> InstalledExtension {
        var id = staged.id
        if let storeID = staged.storeID, let existing = installed.first(where: { $0.storeID == storeID }) {
            id = existing.id
            await remove(existing.id, wipeData: false)
        }
        let packageName = staged.packageName == "package.zip" ? "\(id).zip" : id
        try FileManager.default.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)
        let destination = packagesDirectory.appendingPathComponent(packageName)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: staged.stagingDirectory.appendingPathComponent(staged.packageName), to: destination)
        try? FileManager.default.removeItem(at: staged.stagingDirectory)
        let item = InstalledExtension(id: id, name: staged.name, version: staged.version, isEnabled: true,
                                      storeID: staged.storeID, packageName: packageName)
        installed.append(item)
        try saveCatalog()
        scheduleSync()
        await syncTask?.value
        return item
    }

    public func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = installed.firstIndex(where: { $0.id == id }), installed[index].isEnabled != enabled else { return }
        installed[index].isEnabled = enabled
        try? saveCatalog()
        scheduleSync()
    }

    public func remove(_ id: String, wipeData: Bool = true) async {
        guard let item = installed.first(where: { $0.id == id }) else { return }
        installed.removeAll { $0.id == id }
        try? saveCatalog()
        scheduleSync()
        await syncTask?.value
        if wipeData { await wipeStoredData(of: id) }
        try? FileManager.default.removeItem(at: packagesDirectory.appendingPathComponent(item.packageName))
        loadErrors[id] = nil
    }

    // MARK: Loading

    private func scheduleSync() {
        let previous = syncTask
        syncTask = Task { [weak self] in
            await previous?.value
            await self?.performSync()
        }
    }

    private func performSync() async {
        for (profileID, controller) in controllers { await sync(controller, profileID: profileID) }
        revision &+= 1
    }

    private func sync(_ controller: WKWebExtensionController, profileID: UUID) async {
        let wanted = installed.filter(\.isEnabled)
        var current = contexts[profileID] ?? [:]
        for (id, context) in current where !wanted.contains(where: { $0.id == id }) {
            try? controller.unload(context)
            current[id] = nil
        }
        for item in wanted where current[item.id] == nil {
            do {
                let extensionObject = try await WKWebExtension(resourceBaseURL: packagesDirectory.appendingPathComponent(item.packageName))
                let context = WKWebExtensionContext(for: extensionObject)
                context.uniqueIdentifier = item.id
                #if DEBUG
                context.isInspectable = true
                #endif
                // Installing is the consent step, so everything the manifest asks for is granted up front.
                for permission in extensionObject.requestedPermissions { context.setPermissionStatus(.grantedExplicitly, for: permission) }
                for pattern in extensionObject.allRequestedMatchPatterns { context.setPermissionStatus(.grantedExplicitly, for: pattern) }
                try controller.load(context)
                current[item.id] = context
                loadErrors[item.id] = nil
            } catch {
                loadErrors[item.id] = error.localizedDescription
            }
        }
        contexts[profileID] = current
        readyProfiles.insert(profileID)
        for work in waiters.removeValue(forKey: profileID) ?? [] { work() }
    }

    private func wipeStoredData(of id: String) async {
        for controller in controllers.values {
            for context in controller.extensionContexts where context.uniqueIdentifier == id {
                let record = await controller.dataRecord(ofTypes: WKWebExtensionController.allExtensionDataTypes, for: context)
                if let record { await controller.removeData(ofTypes: WKWebExtensionController.allExtensionDataTypes, from: [record]) }
            }
        }
    }

    // MARK: Catalog

    private static func loadCatalog(in directory: URL) -> [InstalledExtension] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("extensions.json")) else { return [] }
        return (try? JSONDecoder().decode([InstalledExtension].self, from: data)) ?? []
    }

    private func saveCatalog() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(installed).write(to: catalogURL, options: .atomic)
    }
}
