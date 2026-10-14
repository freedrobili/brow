import Foundation
import os

/// Reads and writes one Codable value as a JSON file.
public struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    public let url: URL

    private static var logger: Logger { Logger(subsystem: "com.freedrobili.Brow", category: "storage") }

    public init(directory: URL, name: String) {
        url = directory.appendingPathComponent("\(name).json")
    }

    /// `~/Library/Application Support/Brow`
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Brow", isDirectory: true)
    }

    /// Returns nil when the file is missing. A file that fails to decode is
    /// moved aside to `<name>.json.corrupt` so the app starts from empty state.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let corrupt = url.appendingPathExtension("corrupt")
            let fm = FileManager.default
            try? fm.removeItem(at: corrupt)
            try? fm.moveItem(at: url, to: corrupt)
            Self.logger.error("Corrupt \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
