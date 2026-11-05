import UniformTypeIdentifiers
import XCTest
@testable import BrowCore

final class DropRoutingTests: XCTestCase {
    func testTextFilesAreNotTakenForDraggedText() {
        // Accepting public.plain-text made SwiftUI hand over a CSV's contents instead
        // of the file, so CSV and TXT files never reached the shelf.
        for fileType in [UTType.commaSeparatedText, .tabSeparatedText, .plainText, .json, .sourceCode] {
            XCTAssertFalse(DropRouting.textTypes.contains { fileType.conforms(to: $0) }, fileType.identifier)
        }
    }

    func testSelectedTextFromAppsIsStillAccepted() {
        // Browsers and editors put dragged text on the pasteboard as UTF-8 plain text.
        XCTAssertTrue(DropRouting.textTypes.contains { UTType.utf8PlainText.conforms(to: $0) })
    }

    func testFilesAndLinksComeFirst() {
        XCTAssertEqual(DropRouting.acceptedTypes.prefix(2), [.fileURL, .url])
    }
}
