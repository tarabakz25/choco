import Foundation
import Testing
import WebKit
@testable import BrowserRuntime

@Suite("Browser identity")
@MainActor
struct BrowserIdentityTests {
    @Test func configurationAdvertisesSafariToken() {
        let configuration = WKWebViewConfiguration()
        configuration.applyBrowserIdentity()
        let name = configuration.applicationNameForUserAgent ?? ""
        #expect(name.contains("Version/"))
        #expect(name.contains("Safari/"))
    }
}
