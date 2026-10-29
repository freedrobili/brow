import Foundation

/// Learns which "artwork" from a browser is a placeholder rather than a cover.
/// Chromium browsers send their own icon for sites without a usable cover
/// (Spotify), but real images for others (VK video frames). The icon follows the
/// user from one album to the next, while a real cover belongs to one album, so an
/// artwork seen with two different albums is a placeholder. Tracks without an
/// album are told apart by title. Artworks are identified by a hash; placeholders persist.
public struct PlaceholderArtwork: Codable, Equatable, Sendable {
    /// How many recent artworks are remembered while waiting for a second album.
    public static let memoryLimit = 50

    private var placeholders: Set<String> = []
    /// Recent artwork hash → the album (or title) it came with, oldest first.
    private var recent: [Recent] = []

    private struct Recent: Codable, Equatable, Sendable {
        let artwork: String
        let source: String
    }

    public init() {}

    public func isPlaceholder(_ artwork: String) -> Bool {
        placeholders.contains(artwork)
    }

    /// Records a settled artwork/track pair; returns whether the artwork is a placeholder.
    @discardableResult
    public mutating func observe(artwork: String, title: String, album: String) -> Bool {
        if placeholders.contains(artwork) { return true }
        let album = album.trimmingCharacters(in: .whitespacesAndNewlines)
        // Every track of an album shares its cover, so the album, not the title, is the source.
        let source = album.isEmpty ? "title:" + title : "album:" + album
        if let seen = recent.first(where: { $0.artwork == artwork }) {
            guard seen.source != source else { return false }
            placeholders.insert(artwork)
            recent.removeAll { $0.artwork == artwork }
            return true
        }
        recent.append(Recent(artwork: artwork, source: source))
        if recent.count > Self.memoryLimit { recent.removeFirst(recent.count - Self.memoryLimit) }
        return false
    }
}
