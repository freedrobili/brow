import UniformTypeIdentifiers

/// What the notch accepts when something is dropped on it.
public enum DropRouting {
    /// Dragged text, as browsers and editors put it on the pasteboard. Not
    /// public.plain-text: CSV and TXT files conform to it, and SwiftUI would then
    /// hand over a file's contents instead of the file, which never reached the shelf.
    public static let textTypes: [UTType] = [.utf8PlainText]

    /// In priority order: files go to the shelf, web links to Links, text to the clipboard history.
    public static let acceptedTypes: [UTType] = [.fileURL, .url] + textTypes
}
