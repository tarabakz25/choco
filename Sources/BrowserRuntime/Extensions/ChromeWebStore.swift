import Foundation

/// Locates and unwraps extensions published on the Chrome Web Store.
public enum ChromeWebStore {
    /// Chrome extension IDs are 32 letters from a-p.
    public static func extensionID(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isExtensionID(trimmed) { return trimmed }
        guard let url = URL(string: trimmed), let host = url.host?.lowercased(),
              host == "chromewebstore.google.com" || host == "chrome.google.com" else { return nil }
        return url.pathComponents.first(where: isExtensionID)
    }

    /// The extension ID when `url` is a store detail page (`/detail/<name>/<id>`), not a search, category or other store page.
    public static func storeDetailID(of url: URL) -> String? {
        guard let host = url.host?.lowercased(), host == "chromewebstore.google.com" || host == "chrome.google.com" else { return nil }
        let parts = url.pathComponents
        guard let detail = parts.firstIndex(of: "detail") else { return nil }
        return parts.dropFirst(detail + 1).first(where: isExtensionID)
    }

    /// The extension name in a store tab's title, e.g. "Dark Reader" from "Dark Reader - Chrome ウェブストア".
    public static func extensionName(fromPageTitle title: String?) -> String? {
        guard var name = title?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        for suffix in [" - Chrome ウェブストア", " - Chrome Web Store"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    /// `chromeVersion` is announced as `prodversion`; see `ChromeVersionResolver`.
    public static func downloadURL(for id: String, chromeVersion: String = ChromeVersionResolver.fallback) -> URL? {
        guard isExtensionID(id) else { return nil }
        var components = URLComponents(string: "https://clients2.google.com/service/update2/crx")
        components?.queryItems = [
            URLQueryItem(name: "response", value: "redirect"),
            URLQueryItem(name: "prodversion", value: chromeVersion),
            URLQueryItem(name: "acceptformat", value: "crx3"),
            URLQueryItem(name: "x", value: "id=\(id)&installsource=ondemand&uc")
        ]
        return components?.url
    }

    /// Returns the ZIP payload of a CRX2/CRX3 package, or the data unchanged when it is already a ZIP.
    public static func zipPayload(of data: Data) throws -> Data {
        let bytes = [UInt8](data.prefix(16))
        if bytes.starts(with: [0x50, 0x4B]) { return data }
        guard bytes.count >= 12, bytes.starts(with: Array("Cr24".utf8)) else { throw ExtensionError.unsupportedPackage }
        func word(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }
        let start: Int
        switch word(4) {
        case 3: start = 12 + word(8)
        case 2:
            guard bytes.count >= 16 else { throw ExtensionError.unsupportedPackage }
            start = 16 + word(8) + word(12)
        default: throw ExtensionError.unsupportedPackage
        }
        guard start < data.count else { throw ExtensionError.unsupportedPackage }
        let payload = data.dropFirst(start)
        guard payload.starts(with: [0x50, 0x4B]) else { throw ExtensionError.unsupportedPackage }
        return Data(payload)
    }

    private static func isExtensionID(_ text: String) -> Bool {
        text.utf8.count == 32 && text.utf8.allSatisfy { $0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "p") }
    }
}

public enum ExtensionError: LocalizedError, Equatable {
    case unsupportedPackage
    case invalidSource
    case download(String)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPackage: "拡張機能のパッケージを読み取れません。フォルダ、ZIP、CRXのいずれかを指定してください。"
        case .invalidSource: "拡張機能のフォルダ、ZIP、CRXファイル、またはChromeウェブストアのURL・IDを指定してください。"
        case .download(let message): "拡張機能をダウンロードできませんでした。\(message)"
        case .invalid(let message): "この拡張機能は読み込めません。\(message)"
        }
    }
}
