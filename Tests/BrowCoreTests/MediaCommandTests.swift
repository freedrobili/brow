import XCTest
@testable import BrowCore

final class MediaCommandTests: XCTestCase {
    func testEnvironment() {
        XCTAssertEqual(MediaCommand.toggle.environment, ["BROW_MR_COMMAND": "toggle"])
        XCTAssertEqual(MediaCommand.next.environment, ["BROW_MR_COMMAND": "next"])
        XCTAssertEqual(MediaCommand.previous.environment, ["BROW_MR_COMMAND": "previous"])
        XCTAssertEqual(MediaCommand.seek(42.5).environment, ["BROW_MR_COMMAND": "seek", "BROW_MR_ARG": "42.5"])
    }

    func testBackoff() {
        XCTAssertEqual([0, 1, 2, 4, 5, 20].map(Backoff.delay(attempt:)), [1, 2, 4, 16, 30, 30])
    }
}
