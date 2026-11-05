import Foundation

/// ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z and ⇧⌘Z for Brow's text fields. macOS routes them through
/// the app's Edit menu, which an agent app without a menu bar does not have, so
/// Brow sends the actions itself. Keys are matched by physical key code, so they
/// also work with the Russian layout (where ⌘C arrives as "⌘с").
public enum EditShortcut: Equatable, Sendable {
    case copy, paste, cut, selectAll, undo, redo

    public init?(keyCode: UInt16, command: Bool, shift: Bool, option: Bool, control: Bool) {
        guard command, !option, !control else { return nil }
        switch (keyCode, shift) {
        case (8, false): self = .copy
        case (9, false): self = .paste
        case (7, false): self = .cut
        case (0, false): self = .selectAll
        case (6, false): self = .undo
        case (6, true): self = .redo
        default: return nil
        }
    }

    /// The responder-chain action to send.
    public var selectorName: String {
        switch self {
        case .copy: "copy:"
        case .paste: "paste:"
        case .cut: "cut:"
        case .selectAll: "selectAll:"
        case .undo: "undo:"
        case .redo: "redo:"
        }
    }
}
