import BrowCore
import Carbon

/// Registers the global shortcut with Carbon's RegisterEventHotKey, which works
/// in every app without the Accessibility or Input Monitoring permission.
@MainActor
final class HotKeyCenter {
    private let onPress: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.onPress() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// Returns false when another app already holds the combination.
    @discardableResult
    func register(_ choice: HotKeyChoice) -> Bool {
        unregister()
        guard let combination = choice.combination else { return true }
        let id = EventHotKeyID(signature: OSType(0x4252_4F57), id: 1)   // "BROW"
        let status = RegisterEventHotKey(combination.keyCode, combination.modifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKey)
        return status == noErr
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
}
