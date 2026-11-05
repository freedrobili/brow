import XCTest
@testable import BrowCore

final class EditShortcutTests: XCTestCase {
    // ANSI key codes: A=0, Z=6, X=7, C=8, V=9 — the same physical keys in any layout.
    func testStandardEditingShortcuts() {
        XCTAssertEqual(EditShortcut(keyCode: 8, command: true, shift: false, option: false, control: false), .copy)
        XCTAssertEqual(EditShortcut(keyCode: 9, command: true, shift: false, option: false, control: false), .paste)
        XCTAssertEqual(EditShortcut(keyCode: 7, command: true, shift: false, option: false, control: false), .cut)
        XCTAssertEqual(EditShortcut(keyCode: 0, command: true, shift: false, option: false, control: false), .selectAll)
        XCTAssertEqual(EditShortcut(keyCode: 6, command: true, shift: false, option: false, control: false), .undo)
        XCTAssertEqual(EditShortcut(keyCode: 6, command: true, shift: true, option: false, control: false), .redo)
    }

    func testOtherCombinationsAreNotEditingShortcuts() {
        XCTAssertNil(EditShortcut(keyCode: 8, command: false, shift: false, option: false, control: false))   // plain C
        XCTAssertNil(EditShortcut(keyCode: 8, command: true, shift: false, option: true, control: false))    // ⌥⌘C
        XCTAssertNil(EditShortcut(keyCode: 8, command: true, shift: false, option: false, control: true))    // ⌃⌘C
        XCTAssertNil(EditShortcut(keyCode: 11, command: true, shift: false, option: false, control: false))  // ⌘B
    }

    func testSelectorNames() {
        XCTAssertEqual(EditShortcut.copy.selectorName, "copy:")
        XCTAssertEqual(EditShortcut.paste.selectorName, "paste:")
        XCTAssertEqual(EditShortcut.cut.selectorName, "cut:")
        XCTAssertEqual(EditShortcut.selectAll.selectorName, "selectAll:")
        XCTAssertEqual(EditShortcut.undo.selectorName, "undo:")
        XCTAssertEqual(EditShortcut.redo.selectorName, "redo:")
    }
}
