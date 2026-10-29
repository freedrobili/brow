import Foundation

/// Learns which "artwork" from a browser is a placeholder rather than a cover.
/// Chromium browsers send their own icon for sites without a usable cover
/// (Spotify), but real images for others (VK video frames). The icon is the
/// same picture for every track, so an artwork seen with two different titles
/// is a placeholder. Artworks are identified by a hash; placeholders persist.
public struct PlaceholderArtwork: Codable, Equatable, Sendable {
    /// How many recent artworks are remembered while waiting for a second title.
    public static let memoryLimit = 50

    private var placeholders: Set<String> = []
    /// Recent artwork hash → the title it came with, oldest first.
    private var recent: [Recent] = []

    private struct Recent: Codable, Equatable, Sendable {
        let artwork: String
        let title: String
    }

    public init() {}

    public func isPlaceholder(_ artwork: String) -> Bool {
        placeholders.contains(artwork)
    }

    /// Records a settled artwork/title pair; returns whether the artwork is a placeholder.
    @discardableResult
    public mutating func observe(artwork: String, title: String) -> Bool {
        if placeholders.contains(artwork) { return true }
        if let seen = recent.first(where: { $0.artwork == artwork }) {
            guard seen.title != title else { return false }
            placeholders.insert(artwork)
            recent.removeAll { $0.artwork == artwork }
            return true
        }
        recent.append(Recent(artwork: artwork, title: title))
        if recent.count > Self.memoryLimit { recent.removeFirst(recent.count - Self.memoryLimit) }
        return false
    }
}
