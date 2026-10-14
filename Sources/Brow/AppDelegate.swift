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
        startMedia()
        let watcher = ClipboardWatcher { [model] text, types in model.clipboardChanged(text, types: types) }
        watcher.start()
        model.clipboardWatcher = watcher
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.mediaController?.stop()
    }

    private func startMedia() {
        guard let script = Bundle.main.url(forResource: "brow-media", withExtension: "pl"),
              let library = Bundle.main.url(forResource: "libBrowMediaRemote", withExtension: "dylib") else {
            return   // not running from Brow.app: music stays "unavailable"
        }
        let controller = MediaController(scriptURL: script, libraryURL: library) { [model] status in
            model.media = status
        }
        model.mediaController = controller
        controller.start()
    }
}
