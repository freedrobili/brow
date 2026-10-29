import CoreGraphics
import Foundation

public enum PanelTab: String, Codable, Sendable, CaseIterable {
    case shelf, clipboard, screenshots, notes, links
}

public enum PanelState: Equatable, Sendable {
    case collapsed
    /// The cursor is in the notch; still drawn collapsed, opens on the first
    /// `tick` at or after `deadline` unless the cursor leaves first.
    case opening(deadline: Date)
    case expanded
    /// Still drawn expanded; becomes `.collapsed` on the first `tick` at or after `deadline`.
    case collapsing(deadline: Date)
}

/// Decides when the notch panel opens and closes. Time is passed in, so tests need no waiting.
public struct PanelStateMachine: Equatable, Sendable {
    public static let collapseDelay: TimeInterval = 0.3
    /// How long the cursor has to stay in the notch before the panel opens, so
    /// sweeping past the notch does not open it by accident.
    public static let hoverDelay: TimeInterval = 0.2

    public var geometry: NotchGeometry {
        didSet { state = .collapsed }
    }
    public private(set) var state: PanelState = .collapsed
    public private(set) var selectedTab: PanelTab = .shelf
    public var isEditingNote = false

    public var isExpanded: Bool {
        switch state {
        case .expanded, .collapsing: true
        case .collapsed, .opening: false
        }
    }

    public init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    public mutating func mouseMoved(to point: CGPoint, now: Date) {
        switch state {
        case .collapsed:
            if geometry.hoverRect.containsIncludingEdges(point) {
                state = .opening(deadline: now + Self.hoverDelay)
            }
        case .opening:
            if !geometry.hoverRect.containsIncludingEdges(point) { state = .collapsed }
        case .expanded:
            if !geometry.panelRect.containsIncludingEdges(point) && !isEditingNote {
                state = .collapsing(deadline: now + Self.collapseDelay)
            }
        case .collapsing:
            if geometry.panelRect.containsIncludingEdges(point) { state = .expanded }
        }
    }

    /// A file drag over the notch opens the panel on the shelf.
    public mutating func fileDragMoved(to point: CGPoint, now: Date) {
        dragMoved(to: point, now: now, opening: .shelf)
    }

    /// A text drag over the notch opens the panel on the clipboard history.
    public mutating func textDragMoved(to point: CGPoint, now: Date) {
        dragMoved(to: point, now: now, opening: .clipboard)
    }

    /// A web link drag over the notch opens the panel on the saved links.
    public mutating func linkDragMoved(to point: CGPoint, now: Date) {
        dragMoved(to: point, now: now, opening: .links)
    }

    /// Dragging something to the notch is always deliberate, so it opens at once.
    private mutating func dragMoved(to point: CGPoint, now: Date, opening tab: PanelTab) {
        if !isExpanded && geometry.hoverRect.containsIncludingEdges(point) {
            state = .expanded
        } else {
            mouseMoved(to: point, now: now)
        }
        let target = state == .expanded ? geometry.panelRect : geometry.hoverRect
        if target.containsIncludingEdges(point) { select(tab) }
    }

    public mutating func tick(now: Date) {
        switch state {
        case .opening(let deadline) where now >= deadline:
            state = .expanded
        case .collapsing(let deadline) where now >= deadline && !isEditingNote:
            state = .collapsed
        default:
            break
        }
    }

    /// Leaving the notes tab ends note editing: the note disappears without
    /// reporting it, and a stale flag would keep the panel open for good.
    public mutating func select(_ tab: PanelTab) {
        selectedTab = tab
        if tab != .notes { isEditingNote = false }
    }
}

private extension CGRect {
    /// Unlike `contains`, counts the max edges as inside: the cursor pressed
    /// against the top of the screen sits exactly at `maxY`.
    func containsIncludingEdges(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}
