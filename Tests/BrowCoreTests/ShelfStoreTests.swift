import XCTest
@testable import BrowCore

final class ShelfStoreTests: XCTestCase {
    var dir: URL!
    var fileA: URL!
    var folder: URL!
    var s = ShelfStore()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        folder = dir.appendingPathComponent("dir")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileA = dir.appendingPathComponent("a.txt")
        try Data("a".utf8).write(to: fileA)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAddFile() throws {
        try s.add(fileA)
        XCTAssertEqual(s.items.map(\.name), ["a.txt"])
    }

    func testAddFolder() throws {
        try s.add(folder)
        XCTAssertEqual(s.items.count, 1)
    }

    func testSameFileTwiceIsOneItem() throws {
        try s.add(fileA); try s.add(fileA)
        XCTAssertEqual(s.items.count, 1)
    }

    func testRemoveAndRemoveAll() throws {
        try s.add(fileA); try s.add(folder)
        s.remove(id: s.items[0].id)
        XCTAssertEqual(s.items.count, 1)
        s.removeAll()
        XCTAssertTrue(s.items.isEmpty)
    }

    func testDeletedFileDropsOnResolve() throws {
        try s.add(fileA)
        try FileManager.default.removeItem(at: fileA)
        s.resolveAll()
        XCTAssertTrue(s.items.isEmpty)
    }

    func testRenamedFileUpdatesURL() throws {
        try s.add(fileA)
        let b = dir.appendingPathComponent("b.txt")
        try FileManager.default.moveItem(at: fileA, to: b)
        s.resolveAll()
        XCTAssertEqual(s.items.first?.name, "b.txt")
    }

    func testIsInTrash() {
        XCTAssertTrue(ShelfStore.isInTrash(URL(fileURLWithPath: "/Users/x/.Trash/a.txt")))
        XCTAssertTrue(ShelfStore.isInTrash(URL(fileURLWithPath: "/Volumes/USB/.Trashes/501/a.txt")))
        XCTAssertFalse(ShelfStore.isInTrash(URL(fileURLWithPath: "/Users/x/Documents/a.txt")))
    }
}
