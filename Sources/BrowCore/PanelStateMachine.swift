import CoreGraphics
import Foundation

public enum PanelTab: String, Codable, Sendable, CaseIterable {
    case shelf, clipboard, notes
}

public enum PanelState: Equatable, Sendable {
    case collapsed
    case expanded
    /// Still drawn expanded; becomes `.collapsed` on the first `tick` at or after `deadline`.
    case collapsing(deadline: Date)
}

/// Decides when the notch panel opens and closes. Time is passed in, so tests need no waiting.
public struct PanelStateMachine: Sendable {
    public static let collapseDelay: TimeInterval = 0.3

    public var geometry: NotchGeometry {
        didSet { state = .collapsed }
    }
    public private(set) var state: PanelState = .collapsed
    public private(set) var selectedTab: PanelTab = .shelf
    public var isEditingNote = false

    public var isExpanded: Bool { state != .collapsed }

    public init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    public mutating func mouseMoved(to point: CGPoint, now: Date) {
        switch state {
        case .collapsed:
            if geometry.hoverRect.contains(point) { state = .expanded }
        case .expanded:
            if !geometry.panelRect.contains(point) && !isEditingNote {
                state = .collapsing(deadline: now + Self.collapseDelay)
            }
        case .collapsing:
            if geometry.panelRect.contains(point) { state = .expanded }
        }
    }

    public mutating func fileDragMoved(to point: CGPoint, now: Date) {
        mouseMoved(to: point, now: now)
        let target = state == .expanded ? geometry.panelRect : geometry.hoverRect
        if target.contains(point) { selectedTab = .shelf }
    }

    public mutating func tick(now: Date) {
        if case .collapsing(let deadline) = state, now >= deadline, !isEditingNote {
            state = .collapsed
        }
    }

    public mutating func select(_ tab: PanelTab) {
        selectedTab = tab
    }
}
