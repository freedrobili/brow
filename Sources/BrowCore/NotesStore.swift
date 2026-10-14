import Foundation
import os

/// The single quick note. Saves a moment after the last edit; `flush()` saves right away.
@MainActor
public final class NotesStore {
    public private(set) var text: String

    private let store: JSONFileStore<String>
    private let saveDelay: Duration
    private var pendingSave: Task<Void, Never>?
    private static var logger: Logger { Logger(subsystem: "com.freedrobili.Brow", category: "storage") }

    public init(store: JSONFileStore<String>, saveDelay: Duration = .milliseconds(500)) {
        self.store = store
        self.saveDelay = saveDelay
        text = store.load() ?? ""
    }

    public func update(_ text: String) {
        self.text = text
        pendingSave?.cancel()
        pendingSave = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    public func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        save()
    }

    private func save() {
        do {
            try store.save(text)
        } catch {
            Self.logger.error("Saving note failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
