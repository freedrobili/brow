import XCTest
@testable import BrowCore

let mbp14 = NotchScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                            safeAreaTop: 32, leftAreaWidth: 663.5, rightAreaWidth: 663.5)

final class NotchGeometryTests: XCTestCase {
    func testMacBookPro14() {
        let g = NotchGeometry(screen: mbp14)!
        XCTAssertEqual(g.notchRect, CGRect(x: 663.5, y: 950, width: 185, height: 32))
        XCTAssertEqual(g.hoverRect, CGRect(x: 653.5, y: 940, width: 205, height: 42))
        XCTAssertEqual(g.panelRect, CGRect(x: 516, y: 782, width: 480, height: 200))
    }

    func testScreenWithoutNotch() {
        XCTAssertNil(NotchGeometry(screen: NotchScreenInfo(frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                                                           safeAreaTop: 0, leftAreaWidth: nil, rightAreaWidth: nil)))
    }

    func testOffsetScreenAboveLeftOfExternal() {
        var s = mbp14
        s.frame = CGRect(x: -1512, y: 1080, width: 1512, height: 982)
        let g = NotchGeometry(screen: s)!
        XCTAssertEqual(g.notchRect, CGRect(x: -848.5, y: 2030, width: 185, height: 32))
        XCTAssertEqual(g.panelRect, CGRect(x: -996, y: 1862, width: 480, height: 200))
    }
}
