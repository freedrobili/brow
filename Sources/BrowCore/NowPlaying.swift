import Foundation

public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artwork: Data?
    public var duration: TimeInterval?
    public var elapsed: TimeInterval?
    /// When `elapsed` was measured.
    public var timestamp: Date?
    public var isPlaying: Bool
    public var bundleId: String?

    public init(title: String, artist: String, album: String, artwork: Data?, duration: TimeInterval?,
                elapsed: TimeInterval?, timestamp: Date?, isPlaying: Bool, bundleId: String?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.duration = duration
        self.elapsed = elapsed
        self.timestamp = timestamp
        self.isPlaying = isPlaying
        self.bundleId = bundleId
    }

    /// Playback position extrapolated to `now`, clamped to `0...duration`.
    public func position(at now: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        var position = elapsed
        if isPlaying, let timestamp { position += now.timeIntervalSince(timestamp) }
        position = max(0, position)
        if let duration { position = min(position, duration) }
        return position
    }
}

public enum NowPlayingEvent: Equatable, Sendable {
    case playing(NowPlaying)
    case nothing
}

/// Parses one line of the media helper's output (see `BrowMediaRemote`).
public enum NowPlayingParser {
    /// Returns nil for a line that is not a JSON object.
    public static func parse(line: String) -> NowPlayingEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let title = json["title"] as? String, !title.isEmpty else { return .nothing }

        func number(_ key: String) -> Double? { (json[key] as? NSNumber)?.doubleValue }

        return .playing(NowPlaying(
            title: title,
            artist: json["artist"] as? String ?? "",
            album: json["album"] as? String ?? "",
            artwork: (json["artworkBase64"] as? String).flatMap { Data(base64Encoded: $0) },
            duration: number("duration"),
            elapsed: number("elapsed"),
            timestamp: number("timestamp").map { Date(timeIntervalSince1970: $0) },
            isPlaying: (number("playbackRate") ?? 0) > 0,
            bundleId: json["bundleId"] as? String
        ))
    }
}
