import Foundation

public struct ChecklistItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var isDone: Bool
}

/// The to-do list next to the note. Items keep their place when checked, so the
/// list does not jump under the cursor; done items go away with `removeDone()`.
public struct Checklist: Codable, Equatable, Sendable {
    public private(set) var items: [ChecklistItem] = []

    public init() {}

    public var hasDone: Bool { items.contains(where: \.isDone) }

    /// Appends a task; blank text is ignored.
    @discardableResult
    public mutating func add(_ text: String) -> UUID? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let item = ChecklistItem(id: UUID(), text: text, isDone: false)
        items.append(item)
        return item.id
    }

    /// Checks or unchecks a task; returns true when this checked off the last open one.
    @discardableResult
    public mutating func toggle(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].isDone.toggle()
        return items[index].isDone && items.allSatisfy(\.isDone)
    }

    /// A blank name keeps the old text.
    public mutating func rename(id: UUID, to text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].text = text
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func removeDone() {
        items.removeAll(where: \.isDone)
    }
}
