import AppKit
import BrowCore
import Sparkle

/// Sparkle self-updates. The feed and public key live in Info.plist
/// (SUFeedURL, SUPublicEDKey); updates must be signed with the matching key.
@MainActor
final class Updater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    /// Download and install updates without asking (off by default).
    var automaticallyInstallsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    // MARK: SPUUpdaterDelegate

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UpdatePolicy.testFeedURL(from: ProcessInfo.processInfo.environment["BROW_FEED_URL"])
    }

    // MARK: SPUStandardUserDriverDelegate

    /// Brow has no Dock icon, so scheduled update alerts must bring the app forward
    /// or the window would open behind other apps.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                               forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        MainActor.assumeIsolated { NSApp.activate() }
    }
}
