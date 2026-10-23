import Foundation
import Testing
@testable import BrowserRuntime

@Suite("Address input")
struct AddressResolverTests {
    @Test(arguments: ["", " ", "\n\t"])
    func emptyInput(_ input: String) {
        #expect(AddressResolver.resolve(input) == nil)
    }

    @Test(arguments: ["javascript:alert(1)", " JaVaScRiPt:alert(1) ", "data:text/html,hello", "file:///etc/passwd"])
    func unsafeSchemesAreRejected(_ input: String) {
        #expect(AddressResolver.resolve(input) == nil)
    }

    @Test(arguments: [
        ("example.com", "https://example.com"),
        ("example.com:8443/path?q=one#part", "https://example.com:8443/path?q=one#part"),
        ("localhost:3000/a", "http://localhost:3000/a"),
        ("LOCALHOST:3000", "http://LOCALHOST:3000"),
        ("api.localhost/test", "http://api.localhost/test"),
        ("127.0.0.1:8080", "http://127.0.0.1:8080"),
        ("[::1]:8080/a", "http://[::1]:8080/a"),
        ("::1", "http://[::1]"),
        ("[2001:db8::1]:8000", "https://[2001:db8::1]:8000"),
        ("server:8080", "https://server:8080"),
        ("//example.com/path", "https://example.com/path"),
        ("https://localhost:8080", "https://localhost:8080"),
        ("http://example.com/a", "http://example.com/a")
    ])
    func navigationAddress(_ example: (String, String)) {
        #expect(AddressResolver.resolve(example.0)?.absoluteString == example.1)
    }

    @Test(arguments: ["swift", "hello world", "one + two ? 日本語", "test@example.com", "mailto:test@example.com", "ftp://example.com"])
    func searchTextIsEncodedAsAQuery(_ input: String) throws {
        let result = try #require(AddressResolver.resolve(input))
        let components = try #require(URLComponents(url: result, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "duckduckgo.com")
        #expect(components.queryItems == [URLQueryItem(name: "q", value: input)])
    }

    @Test(arguments: ["https://", "https://example..com", "https://exa mple.com", "https://user:password@example.com", "https://example.com:99999", "example.com:99999"])
    func malformedNavigationIsRejected(_ input: String) {
        #expect(AddressResolver.resolve(input) == nil)
    }

    @Test func internationalDomain() throws {
        let result = try #require(AddressResolver.resolve("例え.テスト/検索"))
        #expect(result.scheme == "https")
        #expect(result.host != "duckduckgo.com")
        #expect(result.path == "/検索")
    }
}
