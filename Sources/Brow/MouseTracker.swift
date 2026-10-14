import AppKit

/// Reports the cursor position from anywhere on screen. A drag counts as a file
/// (or text) drag when the drag pasteboard changed since mouse-down and carries
/// file URLs (or plain text).
@MainActor
final class MouseTracker {
    private let onMove: (CGPoint) -> Void
    private let onFileDrag: (CGPoint) -> Void
    private let onTextDrag: (CGPoint) -> Void
    private var monitors: [Any] = []
    private var dragChangeCountAtMouseDown = 0

    init(onMove: @escaping (CGPoint) -> Void,
         onFileDrag: @escaping (CGPoint) -> Void,
         onTextDrag: @escaping (CGPoint) -> Void) {
        self.onMove = onMove
        self.onFileDrag = onFileDrag
        self.onTextDrag = onTextDrag
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
        case .leftMouseDragged where drag.changeCount != dragChangeCountAtMouseDown:
            let types = drag.types ?? []
            if types.contains(.fileURL) {
                onFileDrag(point)
            } else if types.contains(.string) {
                onTextDrag(point)
            } else {
                onMove(point)
            }
        default:
            onMove(point)
        }
    }
}
