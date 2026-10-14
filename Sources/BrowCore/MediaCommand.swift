import Foundation

/// A playback command for the media helper, passed to it through environment variables.
public enum MediaCommand: Equatable, Sendable {
    case toggle, next, previous
    case seek(TimeInterval)

    public var environment: [String: String] {
        switch self {
        case .toggle: ["BROW_MR_COMMAND": "toggle"]
        case .next: ["BROW_MR_COMMAND": "next"]
        case .previous: ["BROW_MR_COMMAND": "previous"]
        case .seek(let seconds): ["BROW_MR_COMMAND": "seek", "BROW_MR_ARG": String(seconds)]
        }
    }
}

/// Restart delays for the media helper: 1, 2, 4 … capped at 30 seconds.
public enum Backoff {
    public static func delay(attempt: Int) -> TimeInterval {
        min(30, pow(2, Double(min(attempt, 10))))
    }
}
