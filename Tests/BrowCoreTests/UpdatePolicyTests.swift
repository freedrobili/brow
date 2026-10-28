import XCTest
@testable import BrowCore

final class UpdatePolicyTests: XCTestCase {
    func testInstalledCopiesCheckForUpdates() {
        XCTAssertTrue(UpdatePolicy.shouldCheckForUpdates(bundlePath: "/Applications/Brow.app"))
        XCTAssertTrue(UpdatePolicy.shouldCheckForUpdates(bundlePath: "/Users/x/Applications/Brow.app"))
    }

    func testDevelopmentCopiesDoNot() {
        XCTAssertFalse(UpdatePolicy.shouldCheckForUpdates(bundlePath: "/Users/x/brow/.build/app.noindex/Brow.app"))
        XCTAssertFalse(UpdatePolicy.shouldCheckForUpdates(bundlePath: "/Users/x/brow/.build/release/Brow"))
    }

    func testTestFeedOnlyFromThisMac() {
        XCTAssertEqual(UpdatePolicy.testFeedURL(from: "http://127.0.0.1:8765/appcast.xml"), "http://127.0.0.1:8765/appcast.xml")
        XCTAssertEqual(UpdatePolicy.testFeedURL(from: "http://localhost:8765/appcast.xml"), "http://localhost:8765/appcast.xml")
        XCTAssertNil(UpdatePolicy.testFeedURL(from: "https://evil.example.com/appcast.xml"))
        XCTAssertNil(UpdatePolicy.testFeedURL(from: "http://127.0.0.1.evil.example.com/appcast.xml"))
        XCTAssertNil(UpdatePolicy.testFeedURL(from: nil))
        XCTAssertNil(UpdatePolicy.testFeedURL(from: "not a url"))
    }
}
