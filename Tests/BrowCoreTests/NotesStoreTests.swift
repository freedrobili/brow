import XCTest
@testable import BrowCore

@MainActor
final class NotesStoreTests: XCTestCase {
    var dir: URL!
    var store: JSONFileStore<String>!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = JSONFileStore<String>(directory: dir, name: "notes")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testDebouncedSave() async throws {
        let n = NotesStore(store: store, saveDelay: .milliseconds(50))
        n.update("a"); n.update("ab")
        XCTAssertNil(store.load())
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(store.load(), "ab")
    }

    func testFlushSavesImmediately() {
        let n = NotesStore(store: store, saveDelay: .seconds(10))
        n.update("x"); n.flush()
        XCTAssertEqual(store.load(), "x")
    }

    func testLoadsExistingText() throws {
        try store.save("old")
        XCTAssertEqual(NotesStore(store: store).text, "old")
    }
}
