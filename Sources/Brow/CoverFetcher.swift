import AppKit
import BrowCore
import os

/// Downloads covers for browser music from the iTunes Search API and remembers
/// them for the session, so each track is looked up once.
@MainActor
final class CoverFetcher {
    private static let logger = Logger(subsystem: "com.freedrobili.Brow", category: "media")
    private static let cacheLimit = 100

    private var covers: [String: Data] = [:]
    /// Tracks the search answered for, found or not; network errors are retried later.
    private var answered: Set<String> = []
    private var running: Set<String> = []
    private let country = Locale.current.region?.identifier ?? "US"
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        return URLSession(configuration: configuration)
    }()

    func cover(artist: String, title: String) -> Data? {
        covers[CoverLookup.cacheKey(artist: artist, title: title)]
    }

    /// Starts a lookup unless one ran already; calls `found` once a cover is cached.
    func lookUp(artist: String, title: String, found: @escaping () -> Void) {
        let key = CoverLookup.cacheKey(artist: artist, title: title)
        guard !answered.contains(key), !running.contains(key),
              let searchURL = CoverLookup.searchURL(artist: artist, title: title, country: country) else { return }
        running.insert(key)
        Task {
            defer { running.remove(key) }
            do {
                let (response, _) = try await session.data(from: searchURL)
                answered.insert(key)
                guard let coverURL = CoverLookup.artworkURL(from: response, artist: artist, title: title) else { return }
                let (image, _) = try await session.data(from: coverURL)
                guard NSImage(data: image) != nil else { return }
                if covers.count >= Self.cacheLimit { covers.removeAll() }
                covers[key] = image
                found()
            } catch {
                Self.logger.info("Cover lookup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
