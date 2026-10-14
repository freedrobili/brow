import XCTest
@testable import BrowCore

final class ClipboardHistoryTests: XCTestCase {
    var h = ClipboardHistory()

    func testNewestFirst() {
        h.add("a"); h.add("b")
        XCTAssertEqual(h.entries.map(\.text), ["b", "a"])
    }

    func testLimit50() {
        for i in 1...55 { h.add("\(i)") }
        XCTAssertEqual(h.entries.count, 50)
        XCTAssertEqual(h.entries.first?.text, "55")
        XCTAssertEqual(h.entries.last?.text, "6")
    }

    func testDuplicateMovesToTop() {
        h.add("a"); h.add("b"); h.add("a")
        XCTAssertEqual(h.entries.map(\.text), ["a", "b"])
    }

    func testConcealedAndTransientSkipped() {
        XCTAssertFalse(h.add("pw", types: ["org.nspasteboard.ConcealedType"]))
        XCTAssertFalse(h.add("tmp", types: ["org.nspasteboard.TransientType"]))
        XCTAssertTrue(h.entries.isEmpty)
    }

    func testBlankSkipped() {
        XCTAssertFalse(h.add(""))
        XCTAssertFalse(h.add("  \n\t"))
        XCTAssertTrue(h.entries.isEmpty)
    }

    func testSearchCaseInsensitiveCyrillic() {
        h.add("Привет мир"); h.add("hello")
        XCTAssertEqual(h.search("ПРИВЕТ").map(\.text), ["Привет мир"])
        XCTAssertEqual(h.search("").count, 2)
    }

    func testLongTextKeptWholePreviewTruncated() {
        h.add(String(repeating: "a", count: 20_000))
        XCTAssertEqual(h.entries[0].text.count, 20_000)
        XCTAssertEqual(h.entries[0].preview.count, 10_000)
    }
}
