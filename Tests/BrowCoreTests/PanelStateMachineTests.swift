import XCTest
@testable import BrowCore

final class PanelStateMachineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1000)
    var m: PanelStateMachine!

    override func setUp() {
        m = PanelStateMachine(geometry: NotchGeometry(screen: mbp14)!)
    }

    func testHoverInNotchExpands() {
        m.mouseMoved(to: CGPoint(x: 756, y: 970), now: t0)
        XCTAssertEqual(m.state, .expanded)
    }

    func testHoverInPaddingBelowExpands() {
        m.mouseMoved(to: CGPoint(x: 756, y: 945), now: t0)
        XCTAssertEqual(m.state, .expanded)
    }

    func testMenuBarBesideNotchDoesNotExpand() {
        m.mouseMoved(to: CGPoint(x: 560, y: 970), now: t0)   // inside panelRect, outside hoverRect
        XCTAssertEqual(m.state, .collapsed)
    }

    func testLeavingCollapsesAfterDelay() {
        m.mouseMoved(to: CGPoint(x: 756, y: 970), now: t0)
        m.mouseMoved(to: CGPoint(x: 100, y: 100), now: t0)
        XCTAssertEqual(m.state, .collapsing(deadline: t0 + 0.3))
        m.tick(now: t0 + 0.29)
        XCTAssertTrue(m.isExpanded)
        m.tick(now: t0 + 0.3)
        XCTAssertEqual(m.state, .collapsed)
    }

    func testReturnBeforeDeadlineCancels() {
        m.mouseMoved(to: CGPoint(x: 756, y: 970), now: t0)
        m.mouseMoved(to: CGPoint(x: 100, y: 100), now: t0)
        m.mouseMoved(to: CGPoint(x: 756, y: 850), now: t0 + 0.1)
        m.tick(now: t0 + 1)
        XCTAssertEqual(m.state, .expanded)
    }

    func testEditingNotePreventsCollapse() {
        m.mouseMoved(to: CGPoint(x: 756, y: 970), now: t0)
        m.isEditingNote = true
        m.mouseMoved(to: CGPoint(x: 100, y: 100), now: t0)
        m.tick(now: t0 + 1)
        XCTAssertEqual(m.state, .expanded)
    }

    func testEditingStartedWhileCollapsingBlocksTick() {
        m.mouseMoved(to: CGPoint(x: 756, y: 970), now: t0)
        m.mouseMoved(to: CGPoint(x: 100, y: 100), now: t0)
        m.isEditingNote = true
        m.tick(now: t0 + 1)
        XCTAssertTrue(m.isExpanded)
    }

    func testFileDragOpensShelf() {
        m.select(.notes)
        m.fileDragMoved(to: CGPoint(x: 756, y: 970), now: t0)
        XCTAssertEqual(m.state, .expanded)
        XCTAssertEqual(m.selectedTab, .shelf)
    }

    func testFileDragElsewhereKeepsCollapsed() {
        m.fileDragMoved(to: CGPoint(x: 100, y: 100), now: t0)
        XCTAssertEqual(m.state, .collapsed)
        XCTAssertEqual(m.selectedTab, .shelf)
    }
}
