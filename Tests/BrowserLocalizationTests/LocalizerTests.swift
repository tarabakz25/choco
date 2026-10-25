@testable import BrowserLocalization
import Foundation
import Testing

struct LocalizerTests {
    @Test func languageResolutionHonorsSavedChoiceAndSupportedSystemLanguages() {
        #expect(AppLanguage.resolve(savedValue: "en", preferredLanguages: ["ja-JP"]) == .en)
        #expect(AppLanguage.resolve(savedValue: "ja", preferredLanguages: ["en-US"]) == .ja)
        #expect(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["ja-JP"]) == .ja)
        #expect(AppLanguage.resolve(savedValue: "unknown", preferredLanguages: ["fr-FR", "en-GB"]) == .en)
        #expect(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["fr-FR", "ja"]) == .ja)
        #expect(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["fr-FR"]) == .en)
    }

    @Test func explicitBundlesTranslateIndependentlyOfHostLanguage() {
        #expect(Localizer(language: .ja).text("New Tab") == "新しいタブ")
        #expect(Localizer(language: .en).text("New Tab") == "New Tab")
        #expect(Localizer(language: .ja).text("Language") == "言語")
        #expect(Localizer(language: .en).text("Unknown future key") == "Unknown future key")
        #expect(Localizer(language: .ja).format("Downloads · %lld", 3) == "ダウンロード中 · 3件")
        #expect(Localizer(language: .en).format("Open Tab · %@", "Work") == "Open Tab · Work")
    }

    @Test func translationTablesHaveMatchingKeysAndFormatArguments() throws {
        let tables = try AppLanguage.allCases.map { language in
            let url = try #require(Localizer.resourceBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue))
            return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let english = try #require(tables.last)
        let japanese = try #require(tables.first)
        #expect(english.count >= 100)
        #expect(Set(english.keys) == Set(japanese.keys))
        let format = try NSRegularExpression(pattern: "%[0-9$]*[a-z@]+")
        func placeholders(_ value: String) -> [String] {
            format.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { (value as NSString).substring(with: $0.range) }
        }
        for (key, value) in english {
            #expect(value == key)
            let translation = try #require(japanese[key])
            #expect(!translation.isEmpty)
            #expect(placeholders(key) == placeholders(translation))
            #expect(Localizer(language: .ja).text(key) == translation)
            #expect(Localizer(language: .en).text(key) == key)
        }
    }
}
