import Foundation
import os

public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var bookmark: Data
    /// Last resolved location of the file.
    public var url: URL

    public init(id: UUID = UUID(), bookmark: Data, url: URL) {
        self.id = id
        self.bookmark = bookmark
        self.url = url
    }

    public var name: String { url.lastPathComponent }
}

/// Files parked on the shelf. Items are references (bookmarks), the files are never copied.
public struct ShelfStore: Codable, Equatable, Sendable {
    public private(set) var items: [ShelfItem]

    private static var logger: Logger { Logger(subsystem: "com.freedrobili.Brow", category: "shelf") }

    public init(items: [ShelfItem] = []) {
        self.items = items
    }

    /// Adding a file that is already on the shelf does nothing.
    public mutating func add(_ url: URL) throws {
        let key = Self.key(url)
        guard !items.contains(where: { Self.key($0.url) == key }) else { return }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        items.append(ShelfItem(bookmark: bookmark, url: url))
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    /// Follows renamed/moved files, refreshes stale bookmarks and drops items
    /// whose file no longer exists or now sits in the Trash.
    public mutating func resolveAll() {
        items = items.compactMap { item in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI],
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path),
                  !Self.isInTrash(url) else {
                Self.logger.info("Dropping shelf item \(item.name, privacy: .public)")
                return nil
            }
            var resolved = item
            resolved.url = url
            if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                resolved.bookmark = fresh
            }
            return resolved
        }
    }

    public static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
