import AppKit

/// Polls the general pasteboard (macOS has no change notification) and reports new text.
@MainActor
final class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private let onText: (String, Set<String>) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    init(onText: @escaping (String, Set<String>) -> Void) {
        self.onText = onText
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

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard let text = pasteboard.string(forType: .string) else { return }
        onText(text, Set(pasteboard.types?.map(\.rawValue) ?? []))
    }
}
