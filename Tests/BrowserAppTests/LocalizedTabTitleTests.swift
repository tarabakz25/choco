@testable import BrowserApp
import BrowserCore
import BrowserLocalization
import Foundation
import Testing

struct LocalizedTabTitleTests {
    @Test func blankTabUsesSelectedLanguageWithoutChangingStoredContent() {
        let tab = BrowserTab(spaceID: UUID())
        let original = tab

        #expect(tab.localizedTitle(using: Localizer(language: .en)) == "New Tab")
        #expect(tab.localizedTitle(using: Localizer(language: .ja)) == "新しいタブ")
        #expect(tab.title == original.title)
        #expect(tab.customTitle == original.customTitle)
        #expect(tab.url == original.url)
        #expect(tab == original)
    }

    @Test(arguments: ["Research notes", "新しいタブ", "New Tab"])
    func customTitlesRemainVerbatimInBothLanguages(customTitle: String) {
        let tab = BrowserTab(spaceID: UUID(), customTitle: customTitle)
        let original = tab

        for language in AppLanguage.allCases {
            #expect(tab.localizedTitle(using: Localizer(language: language)) == customTitle)
        }
        #expect(tab.title == original.title)
        #expect(tab.customTitle == customTitle)
        #expect(tab.url == original.url)
        #expect(tab == original)
    }

    @Test(arguments: ["日本語のページ", "新しいタブ", "New Tab"])
    func websiteTitlesRemainVerbatimInBothLanguages(pageTitle: String) {
        let tab = BrowserTab(spaceID: UUID(), title: pageTitle, url: "https://example.test/page")
        let original = tab

        for language in AppLanguage.allCases {
            #expect(tab.localizedTitle(using: Localizer(language: language)) == pageTitle)
        }
        #expect(tab.title == pageTitle)
        #expect(tab.customTitle == nil)
        #expect(tab.url == original.url)
        #expect(tab == original)
    }

    @Test func archivePresentationDoesNotRewriteArchivedContent() throws {
        let entry = ArchiveEntry(tab: BrowserTab(spaceID: UUID()), archivedAt: Date(timeIntervalSince1970: 123))
        let original = entry
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let storedContent = try encoder.encode(entry)

        #expect(entry.tab.localizedTitle(using: Localizer(language: .en)) == "New Tab")
        #expect(entry.tab.localizedTitle(using: Localizer(language: .ja)) == "新しいタブ")
        #expect(entry.tab.title == original.tab.title)
        #expect(entry.tab.customTitle == original.tab.customTitle)
        #expect(entry.tab.url == original.tab.url)
        #expect(entry == original)
        #expect(try encoder.encode(entry) == storedContent)
    }
}
