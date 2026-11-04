import Foundation

/// Album covers for music playing in a browser. Some sites' covers do not reach
/// macOS (Chrome sends its own icon for Spotify, see `PlaceholderArtwork`), so
/// the cover is looked up in the public iTunes Search API.
public enum CoverLookup {
    /// Browsers and their betas, nightlies and installed web apps
    /// (`com.google.Chrome.app.…`, `com.apple.Safari.WebApp.…`): the id itself or the id plus ".…".
    private static let browsers: [String] = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome",
        "com.microsoft.edgemac", "ru.yandex.desktop.yandex-browser", "com.kagi.kagimacOS",
        "com.duckduckgo.macos.browser",
    ]
    /// Vendors that make only browsers: any of their apps counts (Opera GX, Firefox Developer Edition, Arc, Dia).
    private static let browserVendors: [String] = [
        "org.mozilla.", "com.operasoftware.", "company.thebrowser.", "com.brave.", "com.vivaldi.",
        "org.chromium.", "app.zen-browser.",
    ]

    public static func isBrowser(_ bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return browsers.contains { bundleId == $0 || bundleId.hasPrefix($0 + ".") }
            || browserVendors.contains { bundleId.hasPrefix($0) }
    }

    /// iTunes Search API query for a song; nil without a title.
    public static func searchURL(artist: String, title: String, country: String) -> URL? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let term = [artist.trimmingCharacters(in: .whitespacesAndNewlines), title]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        var parts = URLComponents(string: "https://itunes.apple.com/search")!
        parts.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "country", value: country),
        ]
        return parts.url
    }

    /// The cover of the result whose title (and artist, when known) match; a wrong
    /// cover is worse than none, so other songs of the artist are not used.
    /// Asks for 600×600 instead of the 100×100 thumbnail.
    public static func artworkURL(from response: Data, artist: String, title: String) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return nil }
        let wantedArtist = normalize(artist), wantedTitle = normalize(title)
        guard !wantedTitle.isEmpty else { return nil }
        let match = results.first { result in
            let foundArtist = normalize(result["artistName"] as? String ?? "")
            let foundTitle = normalize(result["trackName"] as? String ?? "")
            let artistMatches = wantedArtist.isEmpty || foundArtist.contains(wantedArtist) || wantedArtist.contains(foundArtist)
            return artistMatches && (foundTitle.contains(wantedTitle) || wantedTitle.contains(foundTitle))
        }
        guard let small = match?["artworkUrl100"] as? String else { return nil }
        return URL(string: small.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
    }

    public static func cacheKey(artist: String, title: String) -> String {
        normalize(artist) + "\u{1F}" + normalize(title)
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
