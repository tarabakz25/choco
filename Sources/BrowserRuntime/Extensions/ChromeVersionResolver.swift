import Foundation

/// Finds the Chrome version to announce to the Web Store (`prodversion`).
/// The store withholds extensions whose `minimum_chrome_version` is newer than the announced one, so a fixed value goes stale.
/// Asks Google's version-history service for the current stable release, caches it, and falls back to `fallback` when offline.
public actor ChromeVersionResolver {
    /// Used only when no live or cached answer exists. Raise it now and then.
    public static let fallback = "145.0.0.0"
    static let timeToLive: TimeInterval = 24 * 60 * 60

    private struct Cached: Codable {
        var version: String
        var fetchedAt: Date
    }

    private let cacheURL: URL?
    private let fetch: @Sendable () async throws -> String
    private let now: @Sendable () -> Date
    private var memory: Cached?

    public init(
        cacheURL: URL? = nil,
        fetch: @escaping @Sendable () async throws -> String = { try await ChromeVersionResolver.fetchLatestStable() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.cacheURL = cacheURL
        self.fetch = fetch
        self.now = now
    }

    /// The stable Chrome version, from cache while it is under a day old, otherwise freshly fetched.
    public func current() async -> String {
        let cached = memory ?? readCache()
        if let cached, now().timeIntervalSince(cached.fetchedAt) < Self.timeToLive, cached.fetchedAt <= now() {
            memory = cached
            return cached.version
        }
        if let version = try? await fetch(), Self.isVersion(version) {
            let fresh = Cached(version: version, fetchedAt: now())
            memory = fresh
            writeCache(fresh)
            return version
        }
        return cached?.version ?? Self.fallback
    }

    static func isVersion(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return (2...4).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
    }

    /// Reads the newest stable macOS release from Google's public version-history API.
    public static func fetchLatestStable() async throws -> String {
        let url = URL(string: "https://versionhistory.googleapis.com/v1/chrome/platforms/mac/channels/stable/versions?pageSize=1&orderBy=version%20desc")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        struct Listing: Decodable { struct Entry: Decodable { var version: String }; var versions: [Entry] }
        guard let version = try JSONDecoder().decode(Listing.self, from: data).versions.first?.version else { throw URLError(.cannotParseResponse) }
        return version
    }

    private func readCache() -> Cached? {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL) else { return nil }
        guard let cached = try? JSONDecoder().decode(Cached.self, from: data), Self.isVersion(cached.version) else { return nil }
        return cached
    }

    private func writeCache(_ cached: Cached) {
        guard let cacheURL, let data = try? JSONEncoder().encode(cached) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}
