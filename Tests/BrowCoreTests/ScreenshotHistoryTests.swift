import XCTest
@testable import BrowCore

final class ScreenshotHistoryTests: XCTestCase {
    var h = ScreenshotHistory()

    func testNewestFirst() {
        let a = ScreenshotEntry(), b = ScreenshotEntry()
        h.add(a); h.add(b)
        XCTAssertEqual(h.entries, [b, a])
    }

    func testLimitEvictsOldest() {
        let entries = (0..<6).map { _ in ScreenshotEntry() }
        var evicted: [ScreenshotEntry] = []
        for entry in entries { evicted += h.add(entry) }
        XCTAssertEqual(h.entries.count, 5)
        XCTAssertEqual(h.entries.first, entries[5])
        XCTAssertEqual(evicted, [entries[0]])
    }

    func testOnlyBarePNGIsScreenshot() {
        XCTAssertTrue(ScreenshotHistory.isScreenshot(itemTypes: [["public.png"]]))
        XCTAssertFalse(ScreenshotHistory.isScreenshot(itemTypes: [["public.png", "public.html", "org.chromium.source-url"]]))
        XCTAssertFalse(ScreenshotHistory.isScreenshot(itemTypes: [["public.tiff"]]))
        XCTAssertFalse(ScreenshotHistory.isScreenshot(itemTypes: [["public.png"], ["public.png"]]))
        XCTAssertFalse(ScreenshotHistory.isScreenshot(itemTypes: []))
    }

    func testRemoveMissingDropsEntriesWithoutFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let kept = ScreenshotEntry(), lost = ScreenshotEntry()
        h.add(lost); h.add(kept)
        try Data([1]).write(to: kept.url(in: dir))
        h.removeMissing(in: dir)
        XCTAssertEqual(h.entries, [kept])
        XCTAssertEqual(kept.url(in: dir).lastPathComponent, "\(kept.id.uuidString).png")
    }
}
