import Foundation
import Testing
import WebKit
@testable import BrowserRuntime

@Suite("Chrome Web Store")
struct ChromeWebStoreTests {
    private let id = "ddkjiahejlhfcafbddmgiahcphecmpfh"

    @Test func findsTheIDInListingURLsAndRawIDs() {
        #expect(ChromeWebStore.extensionID(from: id) == id)
        #expect(ChromeWebStore.extensionID(from: "  \(id)\n") == id)
        #expect(ChromeWebStore.extensionID(from: "https://chromewebstore.google.com/detail/ublock-origin-lite/\(id)?hl=ja") == id)
        #expect(ChromeWebStore.extensionID(from: "https://chrome.google.com/webstore/detail/\(id)") == id)
    }

    @Test func recognisesOnlyStoreDetailPages() throws {
        func detail(_ text: String) throws -> String? { ChromeWebStore.storeDetailID(of: try #require(URL(string: text))) }
        #expect(try detail("https://chromewebstore.google.com/detail/ublock-origin-lite/\(id)?hl=ja") == id)
        #expect(try detail("https://chrome.google.com/webstore/detail/\(id)") == id)
        #expect(try detail("https://chromewebstore.google.com/search/\(id)") == nil)
        #expect(try detail("https://chromewebstore.google.com/category/extensions") == nil)
        #expect(try detail("https://example.com/detail/x/\(id)") == nil)
    }

    @Test func readsTheExtensionNameFromAStoreTabTitle() {
        #expect(ChromeWebStore.extensionName(fromPageTitle: "Dark Reader - Chrome ウェブストア") == "Dark Reader")
        #expect(ChromeWebStore.extensionName(fromPageTitle: "  uBlock Origin Lite - Chrome Web Store ") == "uBlock Origin Lite")
        #expect(ChromeWebStore.extensionName(fromPageTitle: "Item not available") == nil)
        #expect(ChromeWebStore.extensionName(fromPageTitle: " - Chrome ウェブストア") == nil)
        #expect(ChromeWebStore.extensionName(fromPageTitle: nil) == nil)
    }

    @Test func rejectsOtherInput() {
        #expect(ChromeWebStore.extensionID(from: "") == nil)
        #expect(ChromeWebStore.extensionID(from: "ublock") == nil)
        #expect(ChromeWebStore.extensionID(from: String(id.dropLast())) == nil)
        #expect(ChromeWebStore.extensionID(from: id.uppercased()) == nil)
        #expect(ChromeWebStore.extensionID(from: "https://example.com/detail/\(id)") == nil)
        #expect(ChromeWebStore.downloadURL(for: "nope") == nil)
    }

    @Test func downloadURLNamesTheExtension() throws {
        let url = try #require(ChromeWebStore.downloadURL(for: id))
        #expect(url.host == "clients2.google.com")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "x" }?.value?.hasPrefix("id=\(id)&") == true)
        #expect(components.queryItems?.first { $0.name == "acceptformat" }?.value == "crx3")
    }

    @Test func downloadURLAnnouncesTheGivenChromeVersion() throws {
        func prodversion(_ url: URL?) throws -> String? {
            URLComponents(url: try #require(url), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "prodversion" }?.value
        }
        #expect(try prodversion(ChromeWebStore.downloadURL(for: id, chromeVersion: "156.0.8078.74")) == "156.0.8078.74")
        #expect(try prodversion(ChromeWebStore.downloadURL(for: id)) == ChromeVersionResolver.fallback)
    }

    @Test func unwrapsCRXHeaders() throws {
        let zip = Data([0x50, 0x4B, 0x03, 0x04, 1, 2, 3])
        #expect(try ChromeWebStore.zipPayload(of: zip) == zip)

        var crx3 = Data("Cr24".utf8)
        crx3.append(contentsOf: [3, 0, 0, 0, 5, 0, 0, 0, 9, 9, 9, 9, 9])
        crx3.append(zip)
        #expect(try ChromeWebStore.zipPayload(of: crx3) == zip)

        var crx2 = Data("Cr24".utf8)
        crx2.append(contentsOf: [2, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 7, 7, 8, 8, 8])
        crx2.append(zip)
        #expect(try ChromeWebStore.zipPayload(of: crx2) == zip)
    }

    @Test func rejectsPackagesThatAreNotZips() {
        #expect(throws: ExtensionError.unsupportedPackage) { try ChromeWebStore.zipPayload(of: Data("hello world, not a package".utf8)) }
        var truncated = Data("Cr24".utf8)
        truncated.append(contentsOf: [3, 0, 0, 0, 200, 0, 0, 0])
        #expect(throws: ExtensionError.unsupportedPackage) { try ChromeWebStore.zipPayload(of: truncated) }
    }
}

@Suite("Extensions", .serialized, .enabled(if: ProcessInfo.processInfo.environment["OSS_ARC_WEBKIT_TESTS"] == "1", "Requires native WebKit access"))
@MainActor
struct ExtensionManagerTests {
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ExtensionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A Manifest V3 extension whose content script marks every page it runs in.
    private func makeExtension(in parent: URL, name: String = "Marker") throws -> URL {
        let folder = parent.appendingPathComponent("source-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try """
        {"manifest_version": 3, "name": "\(name)", "version": "1.2.3",
         "content_scripts": [{"matches": ["https://example.test/*"], "js": ["marker.js"], "run_at": "document_end"}]}
        """.write(to: folder.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try "document.documentElement.dataset.marker = 'ran';".write(to: folder.appendingPathComponent("marker.js"), atomically: true, encoding: .utf8)
        return folder
    }

    private func waitUntilLoaded(_ manager: ExtensionManager, profileID: UUID) async {
        await withCheckedContinuation { continuation in
            manager.whenReady(profileID: profileID) { continuation.resume() }
        }
    }

    private func marker(in session: WebSession) async throws -> String? {
        session.webView.loadHTMLString("<html><body>page</body></html>", baseURL: URL(string: "https://example.test/")!)
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(50))
            guard !session.webView.isLoading else { continue }
            let value = try await session.webView.evaluateJavaScript("document.documentElement.dataset.marker ?? ''") as? String
            if value == "ran" { return value }
        }
        return nil
    }

    @Test func installsAFolderAndRunsItsContentScript() async throws {
        _ = NSApplication.shared
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ExtensionManager(directory: directory.appendingPathComponent("Extensions"))

        let staged = try await manager.stage(fileURL: makeExtension(in: directory))
        #expect(staged.name == "Marker")
        #expect(staged.version == "1.2.3")
        #expect(manager.installed.isEmpty)
        let item = try await manager.commit(staged)
        #expect(manager.installed == [item])
        #expect(item.isEnabled)

        let profileID = UUID()
        let pool = WebSessionPool()
        pool.extensions = manager
        let session = pool.session(id: UUID(), profileID: profileID)
        #expect(session.webView.configuration.webExtensionController === manager.controller(for: profileID))
        await waitUntilLoaded(manager, profileID: profileID)
        #expect(manager.loadedContexts(profileID: profileID).map(\.item.id) == [item.id])
        #expect(try await marker(in: session) == "ran")
        pool.retainOnly([])
    }

    @Test func installsAZipAndAPersistedCatalogReloadsIt() async throws {
        _ = NSApplication.shared
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try makeExtension(in: directory, name: "Zipped")
        let zip = directory.appendingPathComponent("zipped.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = source
        process.arguments = ["-qr", zip.path, "."]
        try process.run()
        process.waitUntilExit()

        let root = directory.appendingPathComponent("Extensions")
        let manager = ExtensionManager(directory: root)
        let item = try await manager.commit(manager.stage(fileURL: zip))
        #expect(item.name == "Zipped")

        let reopened = ExtensionManager(directory: root)
        #expect(reopened.installed == [item])
        let profileID = UUID()
        _ = reopened.controller(for: profileID)
        await waitUntilLoaded(reopened, profileID: profileID)
        #expect(reopened.loadedContexts(profileID: profileID).count == 1)
    }

    @Test func disablingStopsTheExtensionAndRemovingDeletesIt() async throws {
        _ = NSApplication.shared
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("Extensions")
        let manager = ExtensionManager(directory: root)
        let item = try await manager.commit(manager.stage(fileURL: makeExtension(in: directory)))
        let profileID = UUID()
        _ = manager.controller(for: profileID)
        await waitUntilLoaded(manager, profileID: profileID)
        #expect(manager.loadedContexts(profileID: profileID).count == 1)

        manager.setEnabled(item.id, false)
        try await Task.sleep(for: .milliseconds(300))
        #expect(manager.loadedContexts(profileID: profileID).isEmpty)

        await manager.remove(item.id)
        #expect(manager.installed.isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Packages").path)
        #expect(leftovers.isEmpty)
    }

    @Test func rejectsFoldersWithoutAManifest() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ExtensionManager(directory: directory.appendingPathComponent("Extensions"))
        await #expect(throws: ExtensionError.self) { try await manager.stage(fileURL: directory) }
        await #expect(throws: ExtensionError.self) { try await manager.stage(fileURL: directory.appendingPathComponent("missing")) }
    }
}

private final class Probe: @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    private var _date = Date(timeIntervalSince1970: 1_000_000)
    var result: Result<String, Error> = .success("156.0.8078.74")
    var calls: Int { lock.withLock { _calls } }
    var date: Date {
        get { lock.withLock { _date } }
        set { lock.withLock { _date = newValue } }
    }
    func fetch() throws -> String {
        lock.withLock { _calls += 1 }
        return try result.get()
    }
}

@Suite("Chrome version resolver")
struct ChromeVersionResolverTests {
    private func makeResolver(_ probe: Probe, cacheURL: URL? = nil) -> ChromeVersionResolver {
        ChromeVersionResolver(cacheURL: cacheURL, fetch: { try probe.fetch() }, now: { probe.date })
    }

    @Test func usesTheFetchedVersionAndCachesItForADay() async {
        let probe = Probe()
        let resolver = makeResolver(probe)
        #expect(await resolver.current() == "156.0.8078.74")
        #expect(await resolver.current() == "156.0.8078.74")
        #expect(probe.calls == 1)

        probe.result = .success("157.0.1.2")
        probe.date.addTimeInterval(ChromeVersionResolver.timeToLive + 1)
        #expect(await resolver.current() == "157.0.1.2")
        #expect(probe.calls == 2)
    }

    @Test func fallsBackWhenOfflineAndNothingIsCached() async {
        let probe = Probe()
        probe.result = .failure(URLError(.notConnectedToInternet))
        #expect(await makeResolver(probe).current() == ChromeVersionResolver.fallback)
    }

    @Test func keepsTheStaleVersionWhenARefreshFails() async {
        let probe = Probe()
        let resolver = makeResolver(probe)
        #expect(await resolver.current() == "156.0.8078.74")
        probe.result = .failure(URLError(.timedOut))
        probe.date.addTimeInterval(ChromeVersionResolver.timeToLive * 3)
        #expect(await resolver.current() == "156.0.8078.74")
    }

    @Test func rejectsMalformedVersions() async {
        let probe = Probe()
        probe.result = .success("<html>error</html>")
        #expect(await makeResolver(probe).current() == ChromeVersionResolver.fallback)
        #expect(ChromeVersionResolver.isVersion("156.0.8078.74"))
        #expect(!ChromeVersionResolver.isVersion("156"))
        #expect(!ChromeVersionResolver.isVersion("156..1"))
        #expect(!ChromeVersionResolver.isVersion("1.2.3.4.5"))
        #expect(!ChromeVersionResolver.isVersion("a.b"))
    }

    @Test func persistsTheVersionAcrossLaunches() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ChromeVersion-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheURL = directory.appendingPathComponent("chrome-version.json")
        let probe = Probe()
        #expect(await makeResolver(probe, cacheURL: cacheURL).current() == "156.0.8078.74")

        let offline = Probe()
        offline.result = .failure(URLError(.notConnectedToInternet))
        #expect(await makeResolver(offline, cacheURL: cacheURL).current() == "156.0.8078.74")
        #expect(offline.calls == 0)
    }
}
