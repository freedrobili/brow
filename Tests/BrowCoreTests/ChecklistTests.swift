import XCTest
@testable import BrowCore

final class ChecklistTests: XCTestCase {
    var list = Checklist()

    func testAddsToTheEndAndIgnoresBlankText() {
        list.add("Купить молоко")
        list.add("  Позвонить в сервис ")
        XCTAssertNil(list.add("   "))
        XCTAssertEqual(list.items.map(\.text), ["Купить молоко", "Позвонить в сервис"])
        XCTAssertTrue(list.items.allSatisfy { !$0.isDone })
    }

    func testToggleMarksAndUnmarks() throws {
        let id = try XCTUnwrap(list.add("Задача"))
        list.add("Другая")
        list.toggle(id: id)
        XCTAssertTrue(list.items[0].isDone)
        list.toggle(id: id)
        XCTAssertFalse(list.items[0].isDone)
    }

    func testToggleReportsWhenEverythingIsDone() throws {
        let a = try XCTUnwrap(list.add("A")), b = try XCTUnwrap(list.add("B"))
        XCTAssertFalse(list.toggle(id: a))   // B is still open
        XCTAssertTrue(list.toggle(id: b))    // that was the last one
        XCTAssertFalse(list.toggle(id: b))   // un-checking is not a celebration
    }

    func testDoneItemsStayInPlace() throws {
        let a = try XCTUnwrap(list.add("A"))
        list.add("B")
        list.toggle(id: a)
        XCTAssertEqual(list.items.map(\.text), ["A", "B"])
    }

    func testRenameKeepsOldTextWhenNewIsBlank() throws {
        let id = try XCTUnwrap(list.add("Старое"))
        list.rename(id: id, to: "  Новое ")
        XCTAssertEqual(list.items[0].text, "Новое")
        list.rename(id: id, to: "  ")
        XCTAssertEqual(list.items[0].text, "Новое")
    }

    func testRemoveAndRemoveDone() throws {
        let a = try XCTUnwrap(list.add("A")), b = try XCTUnwrap(list.add("B"))
        list.add("C")
        XCTAssertFalse(list.hasDone)
        list.toggle(id: b)
        XCTAssertTrue(list.hasDone)
        list.removeDone()
        XCTAssertEqual(list.items.map(\.text), ["A", "C"])
        list.remove(id: a)
        XCTAssertEqual(list.items.map(\.text), ["C"])
    }
}
