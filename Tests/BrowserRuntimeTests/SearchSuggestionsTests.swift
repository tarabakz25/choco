import Foundation
import Testing
@testable import BrowserRuntime

@Suite("Search suggestions")
struct SearchSuggestionsTests {
    private let sample = Data("""
    ["github",["github copilot","https://github.co.jp/","github\\u3068\\u306F","http://github.com","github pages","javascript:alert(1)"],
     ["","GitHub Japan","","","",""],[],
     {"google:suggesttype":["QUERY","NAVIGATION","QUERY","NAVIGATION","QUERY","NAVIGATION"]}]
    """.utf8)

    @Test func splitsQueriesFromLinks() {
        let result = SearchSuggestionService.parse(sample)
        #expect(result.queries == ["github copilot", "githubとは", "github pages"])
        #expect(result.links.map(\.url.absoluteString) == ["https://github.co.jp/", "http://github.com"])
        #expect(result.links.map(\.title) == ["GitHub Japan", "github.com"])
    }

    @Test func dropsTheTypedTextAndHonoursTheLimit() {
        let result = SearchSuggestionService.parse(sample, excluding: "GITHUB COPILOT", limit: 1)
        #expect(result.queries == ["githubとは"])
        #expect(result.links.count == 1)
    }

    @Test(arguments: ["", "{}", "[]", "[\"q\"]", "not json"])
    func malformedResponsesAreEmpty(_ text: String) {
        #expect(SearchSuggestionService.parse(Data(text.utf8)) == .empty)
    }

    @Test func onlySearchTextLeavesTheDevice() {
        #expect(SearchSuggestionService.isSearchText("swift ui"))
        #expect(!SearchSuggestionService.isSearchText("example.com"))
        #expect(!SearchSuggestionService.isSearchText("https://example.com/a"))
        #expect(!SearchSuggestionService.isSearchText("localhost:3000"))
        #expect(!SearchSuggestionService.isSearchText("   "))
    }

    @Test func requestsAreSkippedForAddresses() async {
        let service = SearchSuggestionService { _ in Issue.record("unexpected request"); return Data() }
        #expect(await service.suggestions(for: "example.com") == .empty)
    }

    @Test func failedRequestsAreEmpty() async {
        let service = SearchSuggestionService { _ in throw URLError(.timedOut) }
        #expect(await service.suggestions(for: "swift") == .empty)
    }
}
