import BrowCore
import Foundation
import os
import ServiceManagement

/// "Open at login" through `SMAppService`; Brow shows up in
/// System Settings → General → Login Items like any other app.
@MainActor
enum LoginItem {
    private static let decidedKey = "loginItemDecided"
    private static let logger = Logger(subsystem: "com.freedrobili.Brow", category: "login")

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Turns autostart on for a freshly installed copy, once.
    static func autoEnableIfNeeded() {
        let decided = UserDefaults.standard.bool(forKey: decidedKey)
        guard LoginItemPolicy.shouldAutoEnable(bundlePath: Bundle.main.bundlePath, userHasDecided: decided) else { return }
        UserDefaults.standard.set(true, forKey: decidedKey)
        apply(true)
    }

    /// The user's own choice from the menu; Brow never overrides it afterwards.
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(true, forKey: decidedKey)
        apply(enabled)
    }

    private static func apply(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            logger.error("Login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription, privacy: .public)")
        }
        if enabled && service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
