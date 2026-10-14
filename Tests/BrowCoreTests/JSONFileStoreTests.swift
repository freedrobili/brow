import XCTest
@testable import BrowCore

final class JSONFileStoreTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRoundTripCreatesDirectory() throws {
        let store = JSONFileStore<[String]>(directory: dir, name: "x")
        try store.save(["a", "b"])
        XCTAssertEqual(store.load(), ["a", "b"])
        XCTAssertEqual(store.url.lastPathComponent, "x.json")
    }

    func testMissingFileReturnsNil() {
        XCTAssertNil(JSONFileStore<[String]>(directory: dir, name: "x").load())
    }

    func testCorruptFileIsRenamed() throws {
        let store = JSONFileStore<[String]>(directory: dir, name: "x")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("x.json.corrupt").path))
    }
}
