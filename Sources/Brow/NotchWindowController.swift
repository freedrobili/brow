import AppKit
import BrowCore
import SwiftUI

/// Keeps the panel over the notch of the built-in display and lets clicks
/// through while it is collapsed.
@MainActor
final class NotchWindowController {
    private let panel = NotchPanel()
    private let model: AppModel
    private var keyMonitor: Any?

    init(model: AppModel) {
        self.model = model
        let hostingView = NSHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        model.focusPanel = { [weak self] in self?.panel.makeKey() }
        model.onPanelExpandedChange = { [weak self] expanded in
            self?.panelExpandedChanged(expanded)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        // Clicking another app takes key status away; dropping the first responder
        // ends note editing so the panel can collapse.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.panel.makeFirstResponder(nil)
                self?.model.panelLostKeyFocus()
            }
        }
        // Keys while the panel has the keyboard: Esc closes, ⌘1…⌘5 switch tabs.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let characters = event.charactersIgnoringModifiers
            let inPanel = event.window === self?.panel
            let handled = MainActor.assumeIsolated {
                inPanel && (self?.handleKey(keyCode: keyCode, flags: flags, characters: characters) ?? false)
            }
            return handled ? nil : event
        }
        reposition()
    }

    /// Returns true when the key was used here and must not reach the text fields.
    private func handleKey(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> Bool {
        guard model.isExpanded else { return false }
        // Brow has no Edit menu, so ⌘C/⌘V/⌘X/⌘A/⌘Z would never reach the text fields.
        if let edit = EditShortcut(keyCode: keyCode, command: flags.contains(.command), shift: flags.contains(.shift),
                                   option: flags.contains(.option), control: flags.contains(.control)) {
            return NSApp.sendAction(Selector(edit.selectorName), to: nil, from: nil)
        }
        if keyCode == 53, flags.isEmpty {
            // While typing a note, task or new name Esc belongs to the text field.
            if model.panel?.isEditingNote == true { return false }
            model.closeFromKeyboard()
            return true
        }
        if flags == .command, let digit = characters.flatMap(Int.init),
           (1...PanelTab.allCases.count).contains(digit) {
            model.select(PanelTab.allCases[digit - 1])
            return true
        }
        return false
    }

    private func panelExpandedChanged(_ expanded: Bool) {
        panel.ignoresMouseEvents = !expanded
        // A collapsed panel must not keep typing focus (search field, note):
        // hiding it for a moment hands key status back to the active app.
        if !expanded && panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    private func reposition() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let geometry = NotchGeometry(screen: NotchScreenInfo(
                  frame: screen.frame,
                  safeAreaTop: screen.safeAreaInsets.top,
                  leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
                  rightAreaWidth: screen.auxiliaryTopRightArea?.width))
        else {
            model.panel = nil
            panel.orderOut(nil)
            return
        }
        if model.panel == nil {
            model.panel = model.makePanel(geometry: geometry)
        } else {
            model.panel?.geometry = geometry
        }
        panel.setFrame(geometry.panelRect, display: true)
        panel.orderFrontRegardless()
    }
}
