import XCTest
@testable import BrowCore

final class LoginItemPolicyTests: XCTestCase {
    func testInstalledCopyEnablesOnce() {
        XCTAssertTrue(LoginItemPolicy.shouldAutoEnable(bundlePath: "/Users/x/Applications/Brow.app", userHasDecided: false))
        XCTAssertTrue(LoginItemPolicy.shouldAutoEnable(bundlePath: "/Applications/Brow.app", userHasDecided: false))
    }

    func testRespectsEarlierDecision() {
        XCTAssertFalse(LoginItemPolicy.shouldAutoEnable(bundlePath: "/Users/x/Applications/Brow.app", userHasDecided: true))
    }

    func testDevelopmentBuildNeverEnables() {
        XCTAssertFalse(LoginItemPolicy.shouldAutoEnable(bundlePath: "/Users/x/development/brow/build/Brow.app", userHasDecided: false))
        XCTAssertFalse(LoginItemPolicy.shouldAutoEnable(bundlePath: "/Users/x/development/brow/.build/release/Brow", userHasDecided: false))
    }
}
