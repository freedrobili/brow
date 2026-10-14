import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let bundleIdentifier = "com.freedrobili.Brow"

    private let model = AppModel()
    private var windowController: NotchWindowController?
    private var mouseTracker: MouseTracker?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).count > 1 {
            NSApp.terminate(nil)
            return
        }
        windowController = NotchWindowController(model: model)
        let tracker = MouseTracker(
            onMove: { [model] point in model.mouseMoved(to: point) },
            onFileDrag: { [model] point in model.fileDragMoved(to: point) }
        )
        tracker.start()
        mouseTracker = tracker
    }
}
