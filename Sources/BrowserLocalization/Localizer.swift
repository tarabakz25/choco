import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case ja, en
    public static let storageKey = "appLanguage"
    public var nativeName: String { self == .ja ? "日本語" : "English" }
    public var locale: Locale { Locale(identifier: rawValue) }

    /// UI runs use their own preferences as well as their own browser state.
    public static var defaults: UserDefaults {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--test-session"), arguments.indices.contains(index + 1),
           let session = UUID(uuidString: arguments[index + 1]) {
            return UserDefaults(suiteName: "org.ossarc.browser.uitests.\(session.uuidString)")!
        }
        return .standard
    }

    public static func resolve(savedValue: String?, preferredLanguages: [String]) -> AppLanguage {
        if let savedValue, let language = AppLanguage(rawValue: savedValue) { return language }
        for identifier in preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "ja": return .ja
            case "en": return .en
            default: continue
            }
        }
        return .en
    }

    public static var current: AppLanguage {
        resolve(savedValue: defaults.string(forKey: storageKey), preferredLanguages: Locale.preferredLanguages)
    }
}

/// Resolve an explicit language bundle; changing the app preference needs no restart.
public struct Localizer: Sendable {
    static var resourceBundle: Bundle { Bundle.module }
    public let language: AppLanguage
    public init(language: AppLanguage = .current) { self.language = language }

    public func text(_ key: String) -> String {
        guard let path = Self.resourceBundle.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: language.locale, arguments: arguments)
    }
}
