import XCTest
@testable import BrowCore

final class NowPlayingTests: XCTestCase {
    func testFullLine() {
        let line = #"{"title":"Song","artist":"A","album":"B","artworkBase64":"AQID","duration":200,"elapsed":10,"timestamp":1700000000,"playbackRate":1,"bundleId":"com.apple.Music"}"#
        guard case .playing(let np)? = NowPlayingParser.parse(line: line) else { return XCTFail() }
        XCTAssertEqual(np.title, "Song")
        XCTAssertEqual(np.artist, "A")
        XCTAssertEqual(np.album, "B")
        XCTAssertEqual(np.artwork, Data([1, 2, 3]))
        XCTAssertEqual(np.duration, 200)
        XCTAssertEqual(np.elapsed, 10)
        XCTAssertEqual(np.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(np.isPlaying)
        XCTAssertEqual(np.bundleId, "com.apple.Music")
    }

    func testPartialLine() {
        guard case .playing(let np)? = NowPlayingParser.parse(line: #"{"title":"Song"}"#) else { return XCTFail() }
        XCTAssertEqual(np.artist, "")
        XCTAssertFalse(np.isPlaying)
        XCTAssertNil(np.duration)
    }

    func testNothing() {
        XCTAssertEqual(NowPlayingParser.parse(line: "{}"), .nothing)
        XCTAssertEqual(NowPlayingParser.parse(line: #"{"title":""}"#), .nothing)
    }

    func testMalformed() {
        XCTAssertNil(NowPlayingParser.parse(line: "not json"))
        XCTAssertNil(NowPlayingParser.parse(line: ""))
    }

    func testPosition() {
        let t = Date(timeIntervalSince1970: 0)
        var np = NowPlaying(title: "s", artist: "", album: "", artwork: nil, duration: 12, elapsed: 5,
                            timestamp: t, isPlaying: true, bundleId: nil)
        XCTAssertEqual(np.position(at: t + 3), 8)
        XCTAssertEqual(np.position(at: t + 100), 12)
        np.isPlaying = false
        XCTAssertEqual(np.position(at: t + 3), 5)
        np.elapsed = nil
        XCTAssertNil(np.position(at: t))
    }
}
