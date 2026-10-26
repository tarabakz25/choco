import WebKit

/// WKWebView's default User-Agent has no `Version/x Safari/x` token, so sites such as
/// Google treat it as an unknown legacy browser and serve a reduced page (no favicons,
/// fewer search tabs). Appending the Safari token makes WebKit identify as Safari.
enum BrowserIdentity {
    static let applicationName = "Version/18.4 Safari/605.1.15"
}

extension WKWebViewConfiguration {
    func applyBrowserIdentity() {
        applicationNameForUserAgent = BrowserIdentity.applicationName
    }
}
