import Darwin
import Foundation

/// Resolves deliberate navigation without sending incomplete input to a search service.
public enum AddressResolver {
    public static func resolve(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Extract the prefix before parsing: malformed HTTP URLs can make
        // URLComponents return nil, and must not silently become search queries.
        let schemeRange = text.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression)
        let scheme = schemeRange.map { String(text[$0].dropLast()).lowercased() }
        if let scheme, ["javascript", "data", "file"].contains(scheme) { return nil }
        if scheme == "http" || scheme == "https" {
            return validatedWebURL(text)
        }

        if !text.contains(where: { $0.isWhitespace }), !text.contains("@"), !text.contains("://") {
            var candidate = text.hasPrefix("//") ? String(text.dropFirst(2)) : text
            if isIPv6(candidate) { candidate = "[\(candidate)]" }
            if var components = URLComponents(string: "https://\(candidate)"),
               let host = components.host, validHost(host),
               hostIsNavigation(host, hasPort: components.port != nil) {
                if isLoopback(host) { components.scheme = "http" }
                if let url = components.url, validPort(components.port) { return url }
                return nil
            }
        }

        return searchURL(for: text)
    }

    /// The Google results page for `text`, regardless of whether it looks like an address.
    public static func searchURL(for text: String) -> URL? {
        var search = URLComponents(string: "https://www.google.com/search")!
        search.queryItems = [URLQueryItem(name: "q", value: text)]
        return search.url
    }

    private static func validatedWebURL(_ text: String) -> URL? {
        guard let components = URLComponents(string: text),
              let host = components.host, validHost(host), validPort(components.port),
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        return url
    }

    private static func validPort(_ port: Int?) -> Bool {
        port.map { (1...65535).contains($0) } ?? true
    }

    private static func hostIsNavigation(_ host: String, hasPort: Bool) -> Bool {
        let host = unbracket(host).lowercased()
        return host.contains(".") || host == "localhost" || isIPv6(host) || hasPort
    }

    private static func validHost(_ host: String) -> Bool {
        let host = unbracket(host)
        if isIPv6(host) { return true }
        guard !host.isEmpty, !host.contains(where: { $0.isWhitespace }) else { return false }
        let labels = host.hasSuffix(".") ? String(host.dropLast()).split(separator: ".", omittingEmptySubsequences: false) : host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-") &&
            label.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
        }
    }

    private static func isLoopback(_ host: String) -> Bool {
        let host = unbracket(host).lowercased()
        return host == "localhost" || host.hasSuffix(".localhost") || host == "127.0.0.1" || host == "::1"
    }

    private static func unbracket(_ host: String) -> String {
        host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
    }

    private static func isIPv6(_ host: String) -> Bool {
        var address = in6_addr()
        return host.withCString { inet_pton(AF_INET6, $0, &address) } == 1
    }
}
