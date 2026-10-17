import XCTest
@testable import BrowCore

final class MascotStateTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1000)

    func testIdleByDefault() {
        let m = MascotState(now: t0)
        XCTAssertEqual(m.expression(at: t0 + 1), .idle)
    }

    func testHoverMakesCurious() {
        var m = MascotState(now: t0)
        m.isHovered = true
        XCTAssertEqual(m.expression(at: t0 + 1), .curious)
    }

    func testClickIsHappyForAMoment() {
        var m = MascotState(now: t0)
        m.clicked(now: t0)
        XCTAssertEqual(m.expression(at: t0 + 0.5), .happy)
        XCTAssertEqual(m.expression(at: t0 + MascotState.reactionDuration), .idle)
    }

    func testEventsHaveTheirOwnReactions() {
        var m = MascotState(now: t0)
        m.handle(.fileShelved, now: t0)
        XCTAssertEqual(m.expression(at: t0 + 0.1), .happy)
        m.handle(.textCopied, now: t0 + 2)
        XCTAssertEqual(m.expression(at: t0 + 2.1), .wink)
        m.handle(.screenshotTaken, now: t0 + 4)
        XCTAssertEqual(m.expression(at: t0 + 4.1), .squint)
    }

    func testFallsAsleepWhenCursorRests() {
        var m = MascotState(now: t0)
        m.cursorMoved(now: t0)
        XCTAssertEqual(m.expression(at: t0 + 14), .idle)
        XCTAssertEqual(m.expression(at: t0 + MascotState.drowsyAfter), .drowsy)
        XCTAssertEqual(m.expression(at: t0 + MascotState.asleepAfter), .asleep)
        m.cursorMoved(now: t0 + 40)
        XCTAssertEqual(m.expression(at: t0 + 40.1), .idle)
    }

    func testReactionWakesItUp() {
        var m = MascotState(now: t0)
        m.handle(.fileShelved, now: t0 + 40)
        XCTAssertEqual(m.expression(at: t0 + 40.1), .happy)
        XCTAssertEqual(m.expression(at: t0 + 42), .idle)
    }

    func testOpeningAfterLongAbsencePlaysWakeUpScene() {
        var m = MascotState(now: t0)
        m.panelClosed(now: t0)
        let opened = t0 + MascotState.wakeAfterAbsence
        m.panelOpened(now: opened)
        XCTAssertEqual(m.expression(at: opened + 0.1), .asleep)    // still asleep while the panel unfolds
        XCTAssertEqual(m.expression(at: opened + 0.75), .drowsy)   // eyes half open
        XCTAssertEqual(m.expression(at: opened + 1.2), .waking)    // wide awake, brow up
        XCTAssertEqual(m.expression(at: opened + MascotState.wakingDuration), .idle)
    }

    func testQuickReopenDoesNotWake() {
        var m = MascotState(now: t0)
        m.panelClosed(now: t0)
        m.panelOpened(now: t0 + 5)
        XCTAssertEqual(m.expression(at: t0 + 5.1), .idle)
    }
}

final class MascotGazeTests: XCTestCase {
    let center = CGPoint(x: 100, y: 100)   // global coordinates, y up

    func testFarRightLooksFullyRight() {
        XCTAssertEqual(MascotGaze.pupilOffset(mascotCenter: center, cursor: CGPoint(x: 500, y: 100), maxOffset: 2),
                       CGSize(width: 2, height: 0))
    }

    func testFarAboveLooksUpInViewCoordinates() {
        XCTAssertEqual(MascotGaze.pupilOffset(mascotCenter: center, cursor: CGPoint(x: 100, y: 500), maxOffset: 2),
                       CGSize(width: 0, height: -2))
    }

    func testCursorOnTopOfItLooksStraight() {
        XCTAssertEqual(MascotGaze.pupilOffset(mascotCenter: center, cursor: center, maxOffset: 2), .zero)
    }

    func testNearbyCursorLooksPartway() {
        let offset = MascotGaze.pupilOffset(mascotCenter: center, cursor: CGPoint(x: 100 + MascotGaze.fullTurnDistance / 2, y: 100), maxOffset: 2)
        XCTAssertEqual(offset.width, 1, accuracy: 0.001)
        XCTAssertEqual(offset.height, 0, accuracy: 0.001)
    }
}

final class MascotPlacementTests: XCTestCase {
    func testSitsLeftOfTheNotchCentredOnIt() {
        let g = NotchGeometry(screen: mbp14)!
        XCTAssertEqual(g.mascotRect, CGRect(x: 633.5, y: 954, width: 24, height: 24))
        XCTAssertTrue(g.panelRect.contains(g.mascotRect))
    }
}
