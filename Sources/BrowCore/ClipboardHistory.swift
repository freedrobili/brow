import Foundation

public struct ClipboardEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public var date: Date

    public init(id: UUID = UUID(), text: String, date: Date) {
        self.id = id
        self.text = text
        self.date = date
    }

    /// What the list shows; copying always uses the full `text`.
    public var preview: String { String(text.prefix(ClipboardHistory.previewLimit)) }
}

/// Text clipboard history, newest first.
public struct ClipboardHistory: Codable, Equatable, Sendable {
    public static let limit = 50
    public static let previewLimit = 10_000
    /// Markers password managers put on the pasteboard (nspasteboard.org).
    public static let ignoredTypes: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]

    public private(set) var entries: [ClipboardEntry]

    public init(entries: [ClipboardEntry] = []) {
        self.entries = entries
    }

    /// Returns false when the text is ignored (blank or marked concealed/transient).
    /// Text already in the history moves to the top instead of being duplicated.
    @discardableResult
    public mutating func add(_ text: String, types: Set<String> = [], now: Date = .now) -> Bool {
        guard types.isDisjoint(with: Self.ignoredTypes),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        entries.removeAll { $0.text == text }
        entries.insert(ClipboardEntry(text: text, date: now), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        return true
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    public func search(_ query: String) -> [ClipboardEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }
}
