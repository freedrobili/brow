import AppKit
import BrowCore
import Observation

/// App-wide state shared by the window, the services and the SwiftUI views.
@MainActor
@Observable
final class AppModel {
    /// nil while no screen has a notch.
    var panel: PanelStateMachine? {
        didSet {
            let expanded = panel?.isExpanded ?? false
            if expanded != lastExpanded {
                lastExpanded = expanded
                onPanelExpandedChange?(expanded)
            }
        }
    }

    @ObservationIgnored var onPanelExpandedChange: ((Bool) -> Void)?
    @ObservationIgnored private var lastExpanded = false
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    var isExpanded: Bool { panel?.isExpanded ?? false }

    func mouseMoved(to point: CGPoint) {
        panel?.mouseMoved(to: point, now: .now)
        scheduleTick()
    }

    func fileDragMoved(to point: CGPoint) {
        panel?.fileDragMoved(to: point, now: .now)
        scheduleTick()
    }

    func select(_ tab: PanelTab) {
        panel?.select(tab)
    }

    /// Wakes up at the collapse deadline so the panel closes even if the mouse stops moving.
    private func scheduleTick() {
        guard case .collapsing(let deadline)? = panel?.state else { return }
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.panel?.tick(now: .now)
        }
    }
}
