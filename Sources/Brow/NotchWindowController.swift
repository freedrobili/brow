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
            self?.panel.ignoresMouseEvents = !expanded
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        reposition()
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
