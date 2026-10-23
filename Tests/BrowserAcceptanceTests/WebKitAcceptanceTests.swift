import AppKit
import BrowserCore
import BrowserRuntime
import Foundation
import Testing
import WebKit

/// Opt-in because these tests launch real WebKit helper processes and write isolated website data.
@Suite(.serialized)
@MainActor struct WebKitAcceptanceTests {
    nonisolated private static let enabled = ProcessInfo.processInfo.environment["OSS_ARC_WEBKIT_TESTS"] == "1"

    @Test(.enabled(if: Self.enabled))
    func realPageJavaScriptAndNavigationState() async throws {
        _ = NSApplication.shared
        let session = WebSession(id: UUID(), profileID: UUID())
        defer { session.dispose() }
        session.webView.loadHTMLString("<html><head><title>Acceptance page</title></head><body><input id='entry'><h1>Actual WebKit</h1></body></html>", baseURL: URL(string: "https://ossarc.invalid/"))
        try await waitForPage(session, title: "Acceptance page")
        let result = try await session.webView.evaluateJavaScript("document.getElementById('entry').value = '日本語入力'; document.getElementById('entry').value") as? String
        #expect(result == "日本語入力")
        let sameSession = session.webView
        session.webView.loadHTMLString("<html><title>Second page</title><h1>Second page</h1></html>", baseURL: URL(string: "https://ossarc.invalid/second"))
        try await waitForPage(session, title: "Second page")
        #expect(session.webView === sameSession)
        #expect(session.errorMessage == nil)
    }

    @Test(.enabled(if: Self.enabled))
    func realProfileCookieIsolationAndReopen() async throws {
        _ = NSApplication.shared
        let profileA = UUID(), profileB = UUID()
        let sessionA = WebSession(id: UUID(), profileID: profileA)
        let sessionB = WebSession(id: UUID(), profileID: profileB)
        let token = UUID().uuidString
        let cookie = try #require(HTTPCookie(properties: [.domain: "ossarc.invalid", .path: "/", .name: "ossarc_acceptance", .value: token, .expires: Date(timeIntervalSinceNow: 600), .secure: "TRUE"]))
        let storeA = sessionA.webView.configuration.websiteDataStore.httpCookieStore
        let storeB = sessionB.webView.configuration.websiteDataStore.httpCookieStore
        await storeA.setCookie(cookie)
        let cookiesA = await storeA.allCookies()
        let cookiesB = await storeB.allCookies()
        #expect(cookiesA.contains { $0.name == cookie.name && $0.value == token })
        #expect(!cookiesB.contains { $0.name == cookie.name && $0.value == token })
        sessionA.dispose()
        let reopened = WebSession(id: UUID(), profileID: profileA)
        let reopenedCookies = await reopened.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        #expect(reopenedCookies.contains { $0.name == cookie.name && $0.value == token })
        await reopened.webView.configuration.websiteDataStore.httpCookieStore.deleteCookie(cookie)
        reopened.dispose(); sessionB.dispose()
    }

    @Test(.enabled(if: Self.enabled))
    func restorationLoadsOnlyVisibleSessions() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ossarc-acceptance-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        for n in 0..<20 { store.send(.newTab(url: "https://example.invalid/\(n)")) }
        let tabs = store.state.tabs
        let leading = try #require(tabs.first?.id), trailing = try #require(tabs.last?.id)
        store.send(.setSplit(leading: leading, trailing: trailing))
        await store.flush()
        let restored = BrowserStore(directory: directory)
        #expect(restored.state.tabs.count == tabs.count)
        let split = try #require(restored.state.split)
        #expect(split.leadingTabID == leading && split.trailingTabID == trailing)
        let pool = WebSessionPool()
        let profile = try #require(restored.state.selectedProfile?.id)
        // No initial URL: inspect pool identity without issuing external requests.
        let first = pool.session(id: leading, profileID: profile)
        let second = pool.session(id: trailing, profileID: profile)
        #expect(first !== second)
        #expect(pool.session(id: leading, profileID: profile) === first)
        #expect(first.webView.url == nil && second.webView.url == nil)
        pool.retainOnly([])
    }


    @Test(.enabled(if: Self.enabled))
    func ordinaryEmbeddedFramesRenderWithoutTopLevelError() async throws {
        _ = NSApplication.shared
        let session = WebSession(id: UUID(), profileID: UUID())
        defer { session.dispose() }
        let html = """
        <html><head><title>Embedded frames</title></head><body>
        <script>window.dataFrameLoaded=false;addEventListener('message',e=>{if(e.data==='frame-ready')window.dataFrameLoaded=true;});</script>
        <iframe srcdoc="<p>Embedded srcdoc content</p>"></iframe>
        <iframe src="data:text/html,%3Cscript%3Eparent.postMessage('frame-ready','*')%3C/script%3E"></iframe>
        </body></html>
        """
        session.webView.loadHTMLString(html, baseURL: URL(string: "https://ossarc.invalid/"))
        try await waitForPage(session, title: "Embedded frames")
        var loaded = false
        for _ in 0..<60 {
            loaded = (try? await session.webView.evaluateJavaScript("window.dataFrameLoaded")) as? Bool ?? false
            if loaded { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let content = try await session.webView.evaluateJavaScript("frames[0].document.body.textContent") as? String
        #expect(content?.contains("Embedded srcdoc content") == true)
        #expect(loaded)
        #expect(session.errorMessage == nil)
    }

    private func waitForPage(_ session: WebSession, title: String) async throws {
        for _ in 0..<200 {
            if session.webView.title == title && !session.webView.isLoading { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("WebKit did not load \(title) within 10 seconds: \(session.errorMessage ?? "no delegate error")")
        throw AcceptanceTimeout()
    }
    private struct AcceptanceTimeout: Error {}
}
