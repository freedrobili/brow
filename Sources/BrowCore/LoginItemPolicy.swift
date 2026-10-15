import Foundation

/// When Brow may turn on "open at login" by itself.
public enum LoginItemPolicy {
    /// Only an installed copy (sitting directly in an Applications folder) enables
    /// itself, and only until the user has made a choice: after that their toggle
    /// in the menu or in System Settings wins.
    public static func shouldAutoEnable(bundlePath: String, userHasDecided: Bool) -> Bool {
        guard !userHasDecided else { return false }
        let url = URL(fileURLWithPath: bundlePath)
        return url.pathExtension == "app" && url.deletingLastPathComponent().lastPathComponent == "Applications"
    }
}
