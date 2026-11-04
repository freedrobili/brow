import XCTest
@testable import BrowCore

final class HotKeyChoiceTests: XCTestCase {
    func testDefaultIsOptionCommandB() {
        XCTAssertEqual(HotKeyChoice.default, .optionCommandB)
    }

    func testTitles() {
        XCTAssertEqual(HotKeyChoice.optionCommandB.title, "⌥⌘B")
        XCTAssertEqual(HotKeyChoice.controlOptionSpace.title, "⌃⌥Пробел")
        XCTAssertEqual(HotKeyChoice.controlOptionB.title, "⌃⌥B")
        XCTAssertEqual(HotKeyChoice.off.title, "Выключить")
    }

    func testCarbonKeyCodesAndModifiers() throws {
        // kVK_ANSI_B = 11, kVK_Space = 49; cmdKey = 256, optionKey = 2048, controlKey = 4096.
        let b = try XCTUnwrap(HotKeyChoice.optionCommandB.combination)
        XCTAssertEqual(b.keyCode, 11); XCTAssertEqual(b.modifiers, 256 | 2048)
        let space = try XCTUnwrap(HotKeyChoice.controlOptionSpace.combination)
        XCTAssertEqual(space.keyCode, 49); XCTAssertEqual(space.modifiers, 4096 | 2048)
        let ctrlB = try XCTUnwrap(HotKeyChoice.controlOptionB.combination)
        XCTAssertEqual(ctrlB.keyCode, 11); XCTAssertEqual(ctrlB.modifiers, 4096 | 2048)
        XCTAssertNil(HotKeyChoice.off.combination)
    }

    func testStoredValueRoundTripsAndUnknownFallsBackToDefault() {
        for choice in HotKeyChoice.allCases {
            XCTAssertEqual(HotKeyChoice(stored: choice.rawValue), choice)
        }
        XCTAssertEqual(HotKeyChoice(stored: nil), .default)
        XCTAssertEqual(HotKeyChoice(stored: "something-old"), .default)
    }
}
