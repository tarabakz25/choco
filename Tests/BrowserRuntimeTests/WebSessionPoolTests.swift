import AppKit
import Foundation
import Testing
import WebKit
@testable import BrowserRuntime

@Suite("Web sessions", .serialized, .enabled(if: ProcessInfo.processInfo.environment["OSS_ARC_WEBKIT_TESTS"] == "1", "Requires native WebKit access"))
@MainActor
struct WebSessionPoolTests {
    @Test func sessionIdentityAndProfileReplacement() {
        _ = NSApplication.shared
        let pool = WebSessionPool()
        let id = UUID()
        let firstProfile = UUID()
        let first = pool.session(id: id, profileID: firstProfile)
        #expect(pool.session(id: id, profileID: firstProfile) === first)
        #expect(first.webView.configuration.websiteDataStore.identifier == firstProfile)

        let otherProfile = UUID()
        let replacement = pool.session(id: id, profileID: otherProfile)
        #expect(replacement !== first)
        #expect(replacement.profileID == otherProfile)
        #expect(replacement.webView.configuration.websiteDataStore.identifier == otherProfile)
        let sibling = pool.session(id: UUID(), profileID: otherProfile)
        #expect(sibling.webView.configuration.websiteDataStore === replacement.webView.configuration.websiteDataStore)
        #expect(first.webView.navigationDelegate == nil)
        #expect(first.webView.uiDelegate == nil)
        pool.retainOnly([])
    }

    @Test func popupAdoptsSuppliedDataStoreWithoutLoading() throws {
        _ = NSApplication.shared
        let pool = WebSessionPool()
        let configuration = WKWebViewConfiguration()
        let profileID = UUID()
        let dataStore = WKWebsiteDataStore(forIdentifier: profileID)
        configuration.websiteDataStore = dataStore
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let session = try #require(pool.adopt(id: UUID(), profileID: profileID, configuration: configuration))
        #expect(session.webView.configuration.websiteDataStore === dataStore)
        #expect(session.webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        #expect(session.webView.url == nil)
        #expect(!session.isLoading)
        pool.retainOnly([])
        #expect(session.webView.navigationDelegate == nil)
    }

    @Test func releasedSessionStaysAliveOutsideThePool() {
        _ = NSApplication.shared
        let pool = WebSessionPool()
        let id = UUID(), profileID = UUID()
        let session = pool.session(id: id, profileID: profileID)
        #expect(pool.release(id: id) === session)
        pool.retainOnly([])
        #expect(session.webView.navigationDelegate != nil)
        #expect(pool.release(id: id) == nil)
        #expect(pool.session(id: id, profileID: profileID) !== session)
        pool.retainOnly([])
        session.dispose()
    }

    @Test func popupRejectsForeignOrPrivateDataStoreWithoutReplacingExistingSession() {
        _ = NSApplication.shared
        let pool = WebSessionPool()
        let id = UUID(), expectedProfile = UUID()
        let original = pool.session(id: id, profileID: expectedProfile)
        let foreignConfiguration = WKWebViewConfiguration()
        foreignConfiguration.websiteDataStore = WKWebsiteDataStore(forIdentifier: UUID())
        #expect(pool.adopt(id: id, profileID: expectedProfile, configuration: foreignConfiguration) == nil)
        #expect(pool.session(id: id, profileID: expectedProfile) === original)
        #expect(original.webView.navigationDelegate != nil)
        let privateConfiguration = WKWebViewConfiguration()
        privateConfiguration.websiteDataStore = .nonPersistent()
        #expect(pool.adopt(id: id, profileID: expectedProfile, configuration: privateConfiguration) == nil)
        #expect(pool.session(id: id, profileID: expectedProfile) === original)
        pool.retainOnly([])
    }

    @Test func blockedNavigationAndCleanup() {
        _ = NSApplication.shared
        let pool = WebSessionPool()
        let id = UUID()
        let session = pool.session(id: id, profileID: UUID())
        session.navigate(to: URL(string: "javascript:alert(1)")!)
        #expect(session.errorMessage != nil)
        #expect(session.webView.url == nil)
        session.clearError()
        #expect(session.errorMessage == nil)
        var callbackCalled = false
        session.onClose = { callbackCalled = true }
        pool.remove(id: id)
        session.webViewDidClose(session.webView)
        #expect(!callbackCalled)
        #expect(session.activeDownloadCount == 0)
        #expect(session.downloadProgress == nil)
    }

    @Test func invalidProfileNeverFallsBackToAnotherPersistentProfile() {
        _ = NSApplication.shared
        let invalidID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let session = WebSession(id: UUID(), profileID: invalidID)
        #expect(!session.webView.configuration.websiteDataStore.isPersistent)
        #expect(session.errorMessage != nil)
        session.dispose()
    }
}
