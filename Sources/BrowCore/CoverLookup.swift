import Foundation

/// Album covers for music playing in a browser. Browsers pass the title and
/// artist to macOS but not the site's cover (Chromium sends its own app icon
/// instead), so the cover is looked up in the public iTunes Search API.
public enum CoverLookup {
    private static let browsers = Set([
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
    ]).union(chromiumBrowsers)

    /// These put their own icon where the cover should be.
    private static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
        "company.thebrowser.Browser", "com.microsoft.edgemac", "com.brave.Browser",
        "ru.yandex.desktop.yandex-browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
    ]

    public static func isBrowser(_ bundleId: String?) -> Bool {
        bundleId.map(browsers.contains) ?? false
    }

    /// True when the "artwork" from this app is its icon rather than a cover.
    public static func sendsPlaceholderArtwork(_ bundleId: String?) -> Bool {
        bundleId.map(chromiumBrowsers.contains) ?? false
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
