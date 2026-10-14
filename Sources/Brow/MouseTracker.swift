import AppKit

/// Reports the cursor position from anywhere on screen. A drag counts as a file
/// drag when the drag pasteboard changed since mouse-down and carries file URLs.
@MainActor
final class MouseTracker {
    private let onMove: (CGPoint) -> Void
    private let onFileDrag: (CGPoint) -> Void
    private var monitors: [Any] = []
    private var dragChangeCountAtMouseDown = 0

    init(onMove: @escaping (CGPoint) -> Void, onFileDrag: @escaping (CGPoint) -> Void) {
        self.onMove = onMove
        self.onFileDrag = onFileDrag
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        let drag = NSPasteboard(name: .drag)
        switch event.type {
        case .leftMouseDown:
            dragChangeCountAtMouseDown = drag.changeCount
            onMove(point)
        case .leftMouseDragged where drag.changeCount != dragChangeCountAtMouseDown
            && drag.types?.contains(.fileURL) == true:
            onFileDrag(point)
        default:
            onMove(point)
        }
    }
}
