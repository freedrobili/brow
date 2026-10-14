import AppKit
import BrowCore
import Observation
import os

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

    var media: MediaStatus = .unavailable
    var clipboard: ClipboardHistory
    @ObservationIgnored var mediaController: MediaController?
    @ObservationIgnored var clipboardWatcher: ClipboardWatcher?
    @ObservationIgnored private let clipboardStore = JSONFileStore<ClipboardHistory>(
        directory: JSONFileStore<ClipboardHistory>.defaultDirectory, name: "clipboard")
    @ObservationIgnored private let logger = Logger(subsystem: "com.freedrobili.Brow", category: "storage")

    @ObservationIgnored var onPanelExpandedChange: ((Bool) -> Void)?
    @ObservationIgnored private var lastExpanded = false
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    var isExpanded: Bool { panel?.isExpanded ?? false }

    init() {
        clipboard = clipboardStore.load() ?? ClipboardHistory()
    }

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

    func sendMedia(_ command: MediaCommand) {
        mediaController?.send(command)
    }

    func clipboardChanged(_ text: String, types: Set<String>) {
        if clipboard.add(text, types: types) { persist(clipboard, to: clipboardStore) }
    }

    /// Copies an entry back without reordering the list under the cursor.
    func copyFromHistory(_ entry: ClipboardEntry) {
        clipboardWatcher?.copy(entry.text)
    }

    private func persist<Value>(_ value: Value, to store: JSONFileStore<Value>) {
        do {
            try store.save(value)
        } catch {
            logger.error("Saving \(store.url.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
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
