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
                if expanded {
                    refreshShelf()
                    launchAtLogin = LoginItem.isEnabled   // may have changed in System Settings
                    mascot.panelOpened(now: .now)
                } else {
                    mascot.panelClosed(now: .now)
                }
                onPanelExpandedChange?(expanded)
            }
        }
    }

    var media: MediaStatus = .unavailable
    var mascot = MascotState(now: .now)
    /// Global cursor position, updated only while the panel is open (the mascot looks at it).
    var cursor: CGPoint = .zero
    var launchAtLogin = false
    var clipboard: ClipboardHistory
    var shelf: ShelfStore
    var screenshots: ScreenshotHistory
    var noteText: String {
        didSet { notes.update(noteText) }
    }
    @ObservationIgnored var mediaController: MediaController?
    @ObservationIgnored var clipboardWatcher: ClipboardWatcher?
    @ObservationIgnored private let clipboardStore: JSONFileStore<ClipboardHistory>
    @ObservationIgnored private let shelfStore: JSONFileStore<ShelfStore>
    @ObservationIgnored private let screenshotsStore: JSONFileStore<ScreenshotHistory>
    /// PNG files of `screenshots`, one per entry.
    @ObservationIgnored let screenshotsDirectory: URL
    @ObservationIgnored private var thumbnails: [UUID: NSImage] = [:]
    @ObservationIgnored let notes: NotesStore
    @ObservationIgnored private let logger = Logger(subsystem: "com.freedrobili.Brow", category: "storage")

    @ObservationIgnored var onPanelExpandedChange: ((Bool) -> Void)?
    @ObservationIgnored private var lastExpanded = false
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    var isExpanded: Bool { panel?.isExpanded ?? false }

    /// `directory` holds clipboard.json, shelf.json, screenshots.json, notes.json and
    /// the Screenshots folder; the README renderer points it at a temporary folder
    /// so real data never shows up.
    init(directory: URL = JSONFileStore<String>.defaultDirectory) {
        clipboardStore = JSONFileStore(directory: directory, name: "clipboard")
        shelfStore = JSONFileStore(directory: directory, name: "shelf")
        screenshotsStore = JSONFileStore(directory: directory, name: "screenshots")
        screenshotsDirectory = directory.appendingPathComponent("Screenshots", isDirectory: true)
        notes = NotesStore(store: JSONFileStore(directory: directory, name: "notes"))
        clipboard = clipboardStore.load() ?? ClipboardHistory()
        shelf = shelfStore.load() ?? ShelfStore()
        screenshots = screenshotsStore.load() ?? ScreenshotHistory()
        noteText = notes.text
        refreshShelf()
        tidyScreenshots()
    }

    func mouseMoved(to point: CGPoint) {
        updatePanel { $0.mouseMoved(to: point, now: .now) }
        followCursor(point)
    }

    /// Feeds the mascot while it is visible; skipped when collapsed so global
    /// mouse moves do not redraw anything.
    private func followCursor(_ point: CGPoint) {
        guard isExpanded, let geometry = panel?.geometry else { return }
        cursor = point
        mascot.cursorMoved(now: .now)
        let hovered = geometry.mascotRect.insetBy(dx: -6, dy: -6).contains(point)
        if mascot.isHovered != hovered { mascot.isHovered = hovered }
    }

    func mascotClicked() {
        mascot.clicked(now: .now)
    }

    func fileDragMoved(to point: CGPoint) {
        updatePanel { $0.fileDragMoved(to: point, now: .now) }
    }

    func textDragMoved(to point: CGPoint) {
        updatePanel { $0.textDragMoved(to: point, now: .now) }
    }

    /// Mouse events arrive for every move anywhere on screen; writing `panel`
    /// only when it actually changes keeps SwiftUI from redrawing all day.
    private func updatePanel(_ change: (inout PanelStateMachine) -> Void) {
        guard var next = panel else { return }
        change(&next)
        if next != panel { panel = next }
        scheduleTick()
    }

    func select(_ tab: PanelTab) {
        panel?.select(tab)
    }

    /// Keeps the panel open while the note has focus; on losing it, re-checks the cursor.
    func setEditingNote(_ editing: Bool) {
        panel?.isEditingNote = editing
        if !editing { mouseMoved(to: NSEvent.mouseLocation) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItem.setEnabled(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    func sendMedia(_ command: MediaCommand) {
        mediaController?.send(command)
    }

    func clipboardChanged(_ text: String, types: Set<String>) {
        if clipboard.add(text, types: types) {
            persist(clipboard, to: clipboardStore)
            mascot.handle(.textCopied, now: .now)
        }
    }

    /// Text dropped on the notch goes into the history without touching the pasteboard.
    func addDroppedText(_ text: String) {
        clipboardChanged(text, types: [])
        select(.clipboard)
    }

    /// Copies an entry back without reordering the list under the cursor.
    func copyFromHistory(_ entry: ClipboardEntry) {
        clipboardWatcher?.copy(entry.text)
    }

    /// Removes entries from Brow's history only; the system pasteboard is left alone.
    func removeFromHistory(_ id: UUID) {
        clipboard.remove(id: id)
        persist(clipboard, to: clipboardStore)
    }

    func clearHistory() {
        clipboard.removeAll()
        persist(clipboard, to: clipboardStore)
    }

    func removeScreenshot(_ id: UUID) {
        if let removed = screenshots.remove(id: id) { deleteScreenshotFile(removed) }
        persist(screenshots, to: screenshotsStore)
    }

    func clearScreenshots() {
        screenshots.removeAll().forEach(deleteScreenshotFile)
        persist(screenshots, to: screenshotsStore)
    }

    private func deleteScreenshotFile(_ entry: ScreenshotEntry) {
        try? FileManager.default.removeItem(at: entry.url(in: screenshotsDirectory))
        thumbnails[entry.id] = nil
    }

    func screenshotTaken(_ png: Data) {
        let entry = ScreenshotEntry()
        do {
            try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
            try png.write(to: entry.url(in: screenshotsDirectory), options: .atomic)
        } catch {
            logger.error("Saving screenshot failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        screenshots.add(entry).forEach(deleteScreenshotFile)
        persist(screenshots, to: screenshotsStore)
        mascot.handle(.screenshotTaken, now: .now)
    }

    func copyScreenshot(_ entry: ScreenshotEntry) {
        guard let png = try? Data(contentsOf: entry.url(in: screenshotsDirectory)) else { return }
        clipboardWatcher?.copy(png: png)
    }

    /// A small cached copy for the tab; the originals are full screen size.
    func thumbnail(for entry: ScreenshotEntry) -> NSImage? {
        if let cached = thumbnails[entry.id] { return cached }
        guard let image = NSImage(contentsOf: entry.url(in: screenshotsDirectory)) else { return nil }
        let size = NSSize(width: 160, height: 112)
        let scale = max(size.width / image.size.width, size.height / image.size.height)
        let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumbnail = NSImage(size: target, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        thumbnails[entry.id] = thumbnail
        return thumbnail
    }

    /// Copies the screenshot to a temporary file with a readable name for dragging out.
    func exportScreenshot(_ entry: ScreenshotEntry) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd 'в' HH.mm.ss"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BrowScreenshots", isDirectory: true)
        let target = folder.appendingPathComponent("Снимок экрана \(formatter.string(from: entry.date)).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: entry.url(in: screenshotsDirectory), to: target)
            return target
        } catch {
            logger.error("Exporting screenshot failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Drops entries whose PNG is gone and PNGs no entry refers to.
    private func tidyScreenshots() {
        let before = screenshots
        screenshots.removeMissing(in: screenshotsDirectory)
        if screenshots != before { persist(screenshots, to: screenshotsStore) }
        let known = Set(screenshots.entries.map { $0.url(in: screenshotsDirectory).lastPathComponent })
        let files = (try? FileManager.default.contentsOfDirectory(at: screenshotsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !known.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func addToShelf(_ urls: [URL]) {
        for url in urls {
            do {
                try shelf.add(url)
            } catch {
                logger.error("Shelf add failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        persist(shelf, to: shelfStore)
        select(.shelf)
        mascot.handle(.fileShelved, now: .now)
    }

    func removeFromShelf(_ id: UUID) {
        shelf.remove(id: id)
        persist(shelf, to: shelfStore)
    }

    func clearShelf() {
        shelf.removeAll()
        persist(shelf, to: shelfStore)
    }

    /// Drops items whose files were deleted or trashed, follows renamed ones.
    private func refreshShelf() {
        var refreshed = shelf
        refreshed.resolveAll()
        guard refreshed != shelf else { return }
        shelf = refreshed
        persist(shelf, to: shelfStore)
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
