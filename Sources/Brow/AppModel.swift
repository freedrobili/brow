import AppKit
import BrowCore
import CryptoKit
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
                    refreshLinkInfo()
                    mascot.panelOpened(now: .now)
                } else {
                    mascot.panelClosed(now: .now)
                }
                onPanelExpandedChange?(expanded)
            }
        }
    }

    var media: MediaStatus = .unavailable
    /// Look up covers for browser music online (iTunes Search API); on by default.
    var coverLookupEnabled = UserDefaults.standard.object(forKey: "coverLookupEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(coverLookupEnabled, forKey: "coverLookupEnabled")
            if let lastMediaStatus { mediaStatusChanged(lastMediaStatus) }
        }
    }
    @ObservationIgnored private let covers = CoverFetcher()
    @ObservationIgnored private var lastMediaStatus: MediaStatus?
    @ObservationIgnored private var placeholderArtwork: PlaceholderArtwork
    @ObservationIgnored private let placeholderStore: JSONFileStore<PlaceholderArtwork>
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    var mascot = MascotState(now: .now)
    /// Global cursor position, updated only while the panel is open (the mascot looks at it).
    var cursor: CGPoint = .zero
    var launchAtLogin = false
    /// Mirrors the updater's "install automatically" setting for the menu toggle.
    var autoUpdate = false
    /// nil for development builds, which never update themselves.
    @ObservationIgnored var updater: Updater?
    var clipboard: ClipboardHistory
    var shelf: ShelfStore
    var screenshots: ScreenshotHistory
    var links: LinkStore
    /// The web link currently on the pasteboard, for the «+ из буфера» button.
    var pasteboardLink: URL?
    var noteText: String {
        didSet { notes.update(noteText) }
    }
    @ObservationIgnored var mediaController: MediaController?
    @ObservationIgnored var clipboardWatcher: ClipboardWatcher?
    @ObservationIgnored private let clipboardStore: JSONFileStore<ClipboardHistory>
    @ObservationIgnored private let shelfStore: JSONFileStore<ShelfStore>
    @ObservationIgnored private let screenshotsStore: JSONFileStore<ScreenshotHistory>
    @ObservationIgnored private let linksStore: JSONFileStore<LinkStore>
    @ObservationIgnored private let linkInfo = LinkInfoFetcher()
    /// Makes the panel take keyboard input (set by the window controller).
    @ObservationIgnored var focusPanel: (() -> Void)?
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
        linksStore = JSONFileStore(directory: directory, name: "links")
        // v2: the old rule took every album's cover for a placeholder once two of its
        // tracks played, so what it learned is dropped and learned again.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("artwork-placeholders.json"))
        placeholderStore = JSONFileStore(directory: directory, name: "artwork-placeholders-v2")
        placeholderArtwork = placeholderStore.load() ?? PlaceholderArtwork()
        screenshotsDirectory = directory.appendingPathComponent("Screenshots", isDirectory: true)
        notes = NotesStore(store: JSONFileStore(directory: directory, name: "notes"))
        clipboard = clipboardStore.load() ?? ClipboardHistory()
        shelf = shelfStore.load() ?? ShelfStore()
        screenshots = screenshotsStore.load() ?? ScreenshotHistory()
        links = linksStore.load() ?? LinkStore()
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

    func linkDragMoved(to point: CGPoint) {
        updatePanel { $0.linkDragMoved(to: point, now: .now) }
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

    func checkForUpdates() {
        updater?.checkForUpdates()
    }

    func setAutoUpdate(_ enabled: Bool) {
        updater?.automaticallyInstallsUpdates = enabled
        autoUpdate = updater?.automaticallyInstallsUpdates ?? false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItem.setEnabled(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    /// Browser music keeps real artwork (VK video frames) but drops the browser's
    /// own icon, learned by `PlaceholderArtwork`; without a usable cover, the cover
    /// is looked up online.
    func mediaStatusChanged(_ status: MediaStatus) {
        lastMediaStatus = status
        guard case .playing(var nowPlaying) = status else {
            media = status
            return
        }
        // Artwork that cannot be drawn (broken data, a 1×1 pixel) counts as none, so a cover is looked up.
        if let artwork = nowPlaying.artwork, !Self.isDrawable(artwork) { nowPlaying.artwork = nil }
        guard CoverLookup.isBrowser(nowPlaying.bundleId) else {
            media = .playing(nowPlaying)
            return
        }
        if let artwork = nowPlaying.artwork {
            let fingerprint = Self.fingerprint(artwork)
            if placeholderArtwork.isPlaceholder(fingerprint) {
                nowPlaying.artwork = nil
            } else {
                learnWhenSettled(artwork: fingerprint, title: nowPlaying.title, album: nowPlaying.album)
            }
        }
        if nowPlaying.artwork == nil, coverLookupEnabled {
            if let cover = covers.cover(artist: nowPlaying.artist, title: nowPlaying.title) {
                nowPlaying.artwork = cover
            } else {
                covers.lookUp(artist: nowPlaying.artist, title: nowPlaying.title) { [weak self] in
                    guard let self, let latest = self.lastMediaStatus else { return }
                    self.mediaStatusChanged(latest)   // re-applies the now cached cover if still playing
                }
            }
        }
        media = .playing(nowPlaying)
    }

    /// On a track change Chrome briefly pairs the new title with the previous
    /// artwork, so only pairs that last a second count as evidence.
    private func learnWhenSettled(artwork: String, title: String, album: String) {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            guard self.placeholderArtwork.observe(artwork: artwork, title: title, album: album) else { return }
            self.persist(self.placeholderArtwork, to: self.placeholderStore)
            if let latest = self.lastMediaStatus { self.mediaStatusChanged(latest) }   // drop it now
        }
    }

    private static func isDrawable(_ data: Data) -> Bool {
        guard let image = NSImage(data: data), image.isValid else { return false }
        return image.size.width > 1 && image.size.height > 1
    }

    private static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func sendMedia(_ command: MediaCommand) {
        mediaController?.send(command)
    }

    // MARK: Links

    func addLink(_ url: URL) {
        let id = links.add(url)
        persist(links, to: linksStore)
        select(.links)
        mascot.handle(.linkSaved, now: .now)
        if let link = links.links.first(where: { $0.id == id }), link.pageTitle == nil { fetchInfo(for: link) }
    }

    func addLinkFromPasteboard() {
        if let pasteboardLink { addLink(pasteboardLink) }
    }

    func openLink(_ link: SavedLink) {
        NSWorkspace.shared.open(link.url)
    }

    func copyLink(_ link: SavedLink) {
        clipboardWatcher?.copy(link.url.absoluteString)
    }

    func renameLink(_ id: UUID, to name: String) {
        links.rename(id: id, to: name)
        persist(links, to: linksStore)
    }

    func removeLink(_ id: UUID) {
        links.remove(id: id)
        persist(links, to: linksStore)
    }

    func clearLinks() {
        links.removeAll()
        persist(links, to: linksStore)
    }

    /// Retries pages whose title could not be fetched yet (e.g. offline).
    private func refreshLinkInfo() {
        links.linksNeedingPageInfo.forEach(fetchInfo)
    }

    private func fetchInfo(for link: SavedLink) {
        linkInfo.fetch(link) { [weak self] title, icon in
            guard let self else { return }
            self.links.setPageInfo(id: link.id, title: title ?? link.address, icon: icon)
            self.persist(self.links, to: self.linksStore)
        }
    }

    func clipboardChanged(_ text: String, types: Set<String>) {
        if types.isDisjoint(with: ClipboardHistory.ignoredTypes) { pasteboardLink = WebLink.parse(text) }
        if clipboard.add(text, types: types) { persist(clipboard, to: clipboardStore) }
    }

    /// Text dropped on the notch goes into the history without touching the pasteboard.
    func addDroppedText(_ text: String) {
        clipboardChanged(text, types: [])
        select(.clipboard)
    }

    /// Copies an entry back without reordering the list under the cursor.
    func copyFromHistory(_ entry: ClipboardEntry) {
        clipboardWatcher?.copy(entry.text)
        pasteboardLink = WebLink.parse(entry.text)
        mascot.handle(.textCopied, now: .now)   // the mascot sees it happen in the open panel
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
    }

    func copyScreenshot(_ entry: ScreenshotEntry) {
        guard let png = try? Data(contentsOf: entry.url(in: screenshotsDirectory)) else { return }
        clipboardWatcher?.copy(png: png)
        mascot.handle(.screenshotTaken, now: .now)
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

    /// Wakes up at the open or collapse deadline, so the panel reacts even if the
    /// mouse stops moving.
    private func scheduleTick() {
        let deadline: Date
        switch panel?.state {
        case .opening(let date)?, .collapsing(let date)?: deadline = date
        default: return
        }
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.panel?.tick(now: .now)
        }
    }
}
