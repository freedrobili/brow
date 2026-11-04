import Foundation

/// The global shortcut that opens the panel, picked in the panel's menu.
/// Values are Carbon's: virtual key codes and `cmdKey`/`optionKey`/`controlKey` flags.
public enum HotKeyChoice: String, CaseIterable, Sendable {
    case optionCommandB, controlOptionSpace, controlOptionB, off

    public static let `default` = HotKeyChoice.optionCommandB

    public struct Combination: Equatable, Sendable {
        public let keyCode: UInt32
        public let modifiers: UInt32
    }

    private static let keyB: UInt32 = 11, keySpace: UInt32 = 49
    private static let command: UInt32 = 256, option: UInt32 = 2048, control: UInt32 = 4096

    /// A stored raw value, or the default when missing or no longer known.
    public init(stored: String?) {
        self = stored.flatMap(HotKeyChoice.init(rawValue:)) ?? .default
    }

    public var title: String {
        switch self {
        case .optionCommandB: "⌥⌘B"
        case .controlOptionSpace: "⌃⌥Пробел"
        case .controlOptionB: "⌃⌥B"
        case .off: "Выключить"
        }
    }

    public var combination: Combination? {
        switch self {
        case .optionCommandB: Combination(keyCode: Self.keyB, modifiers: Self.option | Self.command)
        case .controlOptionSpace: Combination(keyCode: Self.keySpace, modifiers: Self.control | Self.option)
        case .controlOptionB: Combination(keyCode: Self.keyB, modifiers: Self.control | Self.option)
        case .off: nil
        }
    }
}
