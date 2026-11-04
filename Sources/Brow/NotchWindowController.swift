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
            MainActor.assumeIsolated { self?.handleKey(event) ?? event }
        }
        reposition()
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard event.window === panel, model.isExpanded else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, flags.isEmpty {
            // While typing a note, task or new name Esc belongs to the text field.
            if model.panel?.isEditingNote == true { return event }
            model.closeFromKeyboard()
            return nil
        }
        if flags == .command, let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
           (1...PanelTab.allCases.count).contains(digit) {
            model.select(PanelTab.allCases[digit - 1])
            return nil
        }
        return event
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
