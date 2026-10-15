import AppKit
import BrowCore

/// Polls the general pasteboard (macOS has no change notification) and reports
/// new text and new ⌘⇧5 screenshots.
@MainActor
final class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private let onText: (String, Set<String>) -> Void
    private let onScreenshot: (Data) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    init(onText: @escaping (String, Set<String>) -> Void, onScreenshot: @escaping (Data) -> Void) {
        self.onText = onText
        self.onScreenshot = onScreenshot
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Puts text on the pasteboard without reporting it back as a new copy.
    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    /// Puts a PNG on the pasteboard without reporting it back as a new screenshot.
    func copy(png: Data) {
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        if let text = pasteboard.string(forType: .string) {
            onText(text, Set(pasteboard.types?.map(\.rawValue) ?? []))
            return
        }
        let itemTypes = (pasteboard.pasteboardItems ?? []).map { $0.types.map(\.rawValue) }
        if ScreenshotHistory.isScreenshot(itemTypes: itemTypes), let png = pasteboard.data(forType: .png) {
            onScreenshot(png)
        }
    }
}
