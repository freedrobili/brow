import Foundation

/// Rules around Sparkle self-updates.
public enum UpdatePolicy {
    /// Only the installed copy (sitting directly in an Applications folder) updates
    /// itself; development builds must not replace themselves with a release.
    public static func shouldCheckForUpdates(bundlePath: String) -> Bool {
        let url = URL(fileURLWithPath: bundlePath)
        return url.pathExtension == "app" && url.deletingLastPathComponent().lastPathComponent == "Applications"
    }

    /// A feed URL from the BROW_FEED_URL environment variable, for testing updates
    /// end to end. Only feeds served by this Mac are accepted.
    public static func testFeedURL(from value: String?) -> String? {
        guard let value, let host = URL(string: value)?.host,
              host == "127.0.0.1" || host == "localhost" else { return nil }
        return value
    }
}
