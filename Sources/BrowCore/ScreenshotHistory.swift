import Foundation

/// One saved screenshot; the image itself lives in `<directory>/<id>.png`.
public struct ScreenshotEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date

    public init(id: UUID = UUID(), date: Date = .now) {
        self.id = id
        self.date = date
    }

    public func url(in directory: URL) -> URL {
        directory.appendingPathComponent("\(id.uuidString).png")
    }
}

/// The last few screenshots taken to the clipboard, newest first.
public struct ScreenshotHistory: Codable, Equatable, Sendable {
    public static let limit = 5

    public private(set) var entries: [ScreenshotEntry]

    public init(entries: [ScreenshotEntry] = []) {
        self.entries = entries
    }

    /// Returns the entries pushed out by the limit, so the caller can delete their files.
    @discardableResult
    public mutating func add(_ entry: ScreenshotEntry) -> [ScreenshotEntry] {
        entries.insert(entry, at: 0)
        guard entries.count > Self.limit else { return [] }
        let evicted = Array(entries[Self.limit...])
        entries.removeLast(entries.count - Self.limit)
        return evicted
    }

    /// Returns the removed entry, so the caller can delete its file.
    @discardableResult
    public mutating func remove(id: UUID) -> ScreenshotEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    /// Returns all removed entries, so the caller can delete their files.
    @discardableResult
    public mutating func removeAll() -> [ScreenshotEntry] {
        defer { entries.removeAll() }
        return entries
    }

    public mutating func removeMissing(in directory: URL) {
        entries.removeAll { !FileManager.default.fileExists(atPath: $0.url(in: directory).path) }
    }

    /// Screenshots from ⌘⇧5 put a single pasteboard item holding nothing but PNG;
    /// images copied from apps carry extra types (HTML, source URL, TIFF).
    /// `itemTypes` are the UTIs of each pasteboard item.
    public static func isScreenshot(itemTypes: [[String]]) -> Bool {
        itemTypes.count == 1 && Set(itemTypes[0]) == ["public.png"]
    }
}
