import BrowMediaRemote
import XCTest

final class JSONLineTests: XCTestCase {
    func testNonFiniteNumbersAreDropped() throws {
        let info: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "Live stream",
            "kMRMediaRemoteNowPlayingInfoDuration": Double.infinity,
            "kMRMediaRemoteNowPlayingInfoElapsedTime": Double.nan,
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": 1.0,
        ]
        let line = try XCTUnwrap(brow_json_line(info, nil))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "Live stream")
        XCTAssertNil(json["duration"])
        XCTAssertNil(json["elapsed"])
        XCTAssertEqual(json["playbackRate"] as? Double, 1)
    }

    func testBundleIdIncluded() throws {
        let line = try XCTUnwrap(brow_json_line(["kMRMediaRemoteNowPlayingInfoTitle": "Song"], "com.google.Chrome"))
        XCTAssertTrue(line.contains(#""bundleId":"com.google.Chrome""#))
    }
}
