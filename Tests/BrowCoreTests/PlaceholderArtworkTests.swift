import XCTest
@testable import BrowCore

final class PlaceholderArtworkTests: XCTestCase {
    var detector = PlaceholderArtwork()

    func testRealCoversAreNotPlaceholders() {
        // VK sends a different video frame for each video.
        XCTAssertFalse(detector.observe(artwork: "frameA", title: "Видео A"))
        XCTAssertFalse(detector.observe(artwork: "frameB", title: "Видео B"))
        XCTAssertFalse(detector.isPlaceholder("frameA"))
        XCTAssertFalse(detector.isPlaceholder("frameB"))
    }

    func testSameArtworkForTwoTitlesIsAPlaceholder() {
        // Chrome sends its own icon for every Spotify track.
        XCTAssertFalse(detector.observe(artwork: "chromeIcon", title: "Таро"))
        XCTAssertTrue(detector.observe(artwork: "chromeIcon", title: "Лампочки"))
        XCTAssertTrue(detector.isPlaceholder("chromeIcon"))
    }

    func testRepeatedUpdatesOfOneTrackAreNotEnough() {
        XCTAssertFalse(detector.observe(artwork: "cover", title: "Песня"))
        XCTAssertFalse(detector.observe(artwork: "cover", title: "Песня"))
        XCTAssertFalse(detector.isPlaceholder("cover"))
    }

    func testRemembersPlaceholdersAcrossLaunches() throws {
        _ = detector.observe(artwork: "chromeIcon", title: "Таро")
        _ = detector.observe(artwork: "chromeIcon", title: "Лампочки")
        let restored = try JSONDecoder().decode(PlaceholderArtwork.self, from: JSONEncoder().encode(detector))
        XCTAssertTrue(restored.isPlaceholder("chromeIcon"))
    }

    func testKeepsOnlyRecentArtworkMemory() {
        for i in 0..<(PlaceholderArtwork.memoryLimit + 10) {
            _ = detector.observe(artwork: "art\(i)", title: "Трек \(i)")
        }
        // The oldest artwork was forgotten, so meeting it with a new title is a fresh start.
        XCTAssertFalse(detector.observe(artwork: "art0", title: "Другой трек"))
    }
}
