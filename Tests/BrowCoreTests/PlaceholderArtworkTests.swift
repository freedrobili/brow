import XCTest
@testable import BrowCore

final class PlaceholderArtworkTests: XCTestCase {
    var detector = PlaceholderArtwork()

    func testRealCoversAreNotPlaceholders() {
        // VK sends a different video frame for each video.
        XCTAssertFalse(detector.observe(artwork: "frameA", title: "Видео A", album: ""))
        XCTAssertFalse(detector.observe(artwork: "frameB", title: "Видео B", album: ""))
        XCTAssertFalse(detector.isPlaceholder("frameA"))
        XCTAssertFalse(detector.isPlaceholder("frameB"))
    }

    func testSameArtworkForTwoTitlesIsAPlaceholder() {
        // Chrome sends its own icon for every Spotify track.
        XCTAssertFalse(detector.observe(artwork: "chromeIcon", title: "Таро", album: ""))
        XCTAssertTrue(detector.observe(artwork: "chromeIcon", title: "Лампочки", album: ""))
        XCTAssertTrue(detector.isPlaceholder("chromeIcon"))
    }

    func testOneAlbumsCoverIsNotAPlaceholder() {
        // Every track of an album comes with the same real cover.
        XCTAssertFalse(detector.observe(artwork: "albumCover", title: "Livin' It Up", album: "Chocolate Starfish"))
        XCTAssertFalse(detector.observe(artwork: "albumCover", title: "Rollin'", album: "Chocolate Starfish"))
        XCTAssertFalse(detector.observe(artwork: "albumCover", title: "My Way", album: "Chocolate Starfish"))
        XCTAssertFalse(detector.isPlaceholder("albumCover"))
    }

    func testSameArtworkForTwoAlbumsIsAPlaceholder() {
        // The browser icon follows the user from one album to the next.
        XCTAssertFalse(detector.observe(artwork: "chromeIcon", title: "Rollin'", album: "Chocolate Starfish"))
        XCTAssertFalse(detector.observe(artwork: "chromeIcon", title: "My Way", album: "Chocolate Starfish"))
        XCTAssertTrue(detector.observe(artwork: "chromeIcon", title: "Numb", album: "Meteora"))
        XCTAssertTrue(detector.isPlaceholder("chromeIcon"))
    }

    func testRepeatedUpdatesOfOneTrackAreNotEnough() {
        XCTAssertFalse(detector.observe(artwork: "cover", title: "Песня", album: ""))
        XCTAssertFalse(detector.observe(artwork: "cover", title: "Песня", album: ""))
        XCTAssertFalse(detector.isPlaceholder("cover"))
    }

    func testRemembersPlaceholdersAcrossLaunches() throws {
        _ = detector.observe(artwork: "chromeIcon", title: "Таро", album: "")
        _ = detector.observe(artwork: "chromeIcon", title: "Лампочки", album: "")
        let restored = try JSONDecoder().decode(PlaceholderArtwork.self, from: JSONEncoder().encode(detector))
        XCTAssertTrue(restored.isPlaceholder("chromeIcon"))
    }

    func testKeepsOnlyRecentArtworkMemory() {
        for i in 0..<(PlaceholderArtwork.memoryLimit + 10) {
            _ = detector.observe(artwork: "art\(i)", title: "Трек \(i)", album: "")
        }
        // The oldest artwork was forgotten, so meeting it with a new title is a fresh start.
        XCTAssertFalse(detector.observe(artwork: "art0", title: "Другой трек", album: ""))
    }
}
