import AppKit
import BrowCore
import SwiftUI

/// Keeps the panel over the notch of the built-in display and lets clicks
/// through while it is collapsed.
@MainActor
final class NotchWindowController {
    private let panel = NotchPanel()
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let hostingView = NSHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
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
            MainActor.assumeIsolated { _ = self?.panel.makeFirstResponder(nil) }
        }
        reposition()
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
            model.panel = PanelStateMachine(geometry: geometry)
        } else {
            model.panel?.geometry = geometry
        }
        panel.setFrame(geometry.panelRect, display: true)
        panel.orderFrontRegardless()
    }
}
