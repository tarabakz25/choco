import Foundation

/// Google's omnibox suggestions for a typed query: related searches and the top links Google would navigate to.
public struct SearchSuggestions: Equatable, Sendable {
    public struct Link: Equatable, Sendable {
        public var url: URL
        public var title: String
        public init(url: URL, title: String) { self.url = url; self.title = title }
    }

    public var queries: [String]
    public var links: [Link]
    public init(queries: [String] = [], links: [Link] = []) { self.queries = queries; self.links = links }
    public static let empty = SearchSuggestions()
}

public struct SearchSuggestionService: Sendable {
    private let fetchData: @Sendable (URL) async throws -> Data

    public init(fetchData: @escaping @Sendable (URL) async throws -> Data) { self.fetchData = fetchData }

    /// Uses an ephemeral session so suggestion requests never share cookies with any Profile.
    public static let google = SearchSuggestionService { url in
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.waitsForConnectivity = false
        var request = URLRequest(url: url)
        request.setValue("text/javascript", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// Only plain search text is sent: input that resolves to a URL stays on this device, like incomplete input in `AddressResolver`.
    public static func isSearchText(_ input: String) -> Bool {
        guard let url = AddressResolver.resolve(input) else { return false }
        return url.host == "www.google.com" && url.path == "/search"
    }

    public func suggestions(for input: String, limit: Int = 4) async -> SearchSuggestions {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSearchText(text),
              var components = URLComponents(string: "https://suggestqueries.google.com/complete/search") else { return .empty }
        components.queryItems = [URLQueryItem(name: "client", value: "chrome"), URLQueryItem(name: "q", value: text)]
        guard let url = components.url, let data = try? await fetchData(url) else { return .empty }
        return Self.parse(data, excluding: text, limit: limit)
    }

    /// Parses `["query", [suggestion…], [description…], [], {"google:suggesttype": [...]}]`.
    /// Navigation entries become links (http/https only); the typed text itself is dropped from the queries.
    public static func parse(_ data: Data, excluding typed: String = "", limit: Int = 4) -> SearchSuggestions {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              root.count > 1, let entries = root[1] as? [String] else { return .empty }
        let descriptions = root.count > 2 ? (root[2] as? [String] ?? []) : []
        let types = (root.count > 4 ? (root[4] as? [String: Any])?["google:suggesttype"] as? [String] : nil) ?? []
        var queries: [String] = [], links: [SearchSuggestions.Link] = []
        for (index, entry) in entries.enumerated() {
            let type = types.indices.contains(index) ? types[index] : "QUERY"
            if type == "NAVIGATION" {
                guard entry.lowercased().hasPrefix("http"), let url = AddressResolver.resolve(entry), links.count < limit else { continue }
                let title = descriptions.indices.contains(index) ? descriptions[index] : ""
                links.append(.init(url: url, title: title.isEmpty ? (url.host ?? entry) : title))
            } else if queries.count < limit, entry.caseInsensitiveCompare(typed) != .orderedSame, !queries.contains(entry) {
                queries.append(entry)
            }
        }
        return SearchSuggestions(queries: queries, links: links)
    }
}
