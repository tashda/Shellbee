import XCTest
@testable import Shellbee

final class ConnectionHistoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        super.tearDown()
    }

    // MARK: - add

    @MainActor
    func testAddInsertsAtFront() {
        let h = ConnectionHistory()
        h.add(makeConfig(host: "first"))
        h.add(makeConfig(host: "second"))
        XCTAssertEqual(h.connections.first?.host, "second")
    }

    @MainActor
    func testAddDeduplicatesByHostPortPath() {
        let h = ConnectionHistory()
        h.add(makeConfig(host: "host", port: 8080))
        h.add(makeConfig(host: "host", port: 8080))
        XCTAssertEqual(h.connections.count, 1)
    }

    @MainActor
    func testAddDuplicateMoveToFront() {
        let h = ConnectionHistory()
        h.add(makeConfig(host: "a"))
        h.add(makeConfig(host: "b"))
        h.add(makeConfig(host: "a"))
        XCTAssertEqual(h.connections.first?.host, "a")
        XCTAssertEqual(h.connections.count, 2)
    }

    @MainActor
    func testMaxTenEntriesEnforced() {
        let h = ConnectionHistory()
        for i in 1...11 {
            h.add(makeConfig(host: "host\(i)"))
        }
        XCTAssertEqual(h.connections.count, 10)
    }

    @MainActor
    func testEleventhEntryDropsOldest() {
        let h = ConnectionHistory()
        for i in 1...11 {
            h.add(makeConfig(host: "host\(i)"))
        }
        XCTAssertFalse(h.connections.contains { $0.host == "host1" })
    }

    // MARK: - remove

    @MainActor
    func testRemoveByConfig() {
        let h = ConnectionHistory()
        let cfg = makeConfig(host: "todelete")
        h.add(cfg)
        h.add(makeConfig(host: "keeper"))
        h.remove(cfg)
        XCTAssertFalse(h.connections.contains { $0.host == "todelete" })
        XCTAssertEqual(h.connections.count, 1)
    }

    @MainActor
    func testRemoveAtOffsets() {
        let h = ConnectionHistory()
        h.add(makeConfig(host: "a"))
        h.add(makeConfig(host: "b"))
        h.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(h.connections.count, 1)
    }

    // MARK: - update

    @MainActor
    func testUpdateReplacesExistingEntry() {
        let h = ConnectionHistory()
        var cfg = makeConfig(host: "original")
        h.add(cfg)
        cfg.authToken = "newtoken"
        h.update(cfg)
        XCTAssertEqual(h.connections.first?.authToken, "newtoken")
    }

    // MARK: - persistence

    @MainActor
    func testPersistsAcrossInstances() {
        let h1 = ConnectionHistory()
        h1.add(makeConfig(host: "persistent"))

        let h2 = ConnectionHistory()
        XCTAssertTrue(h2.connections.contains { $0.host == "persistent" })
    }

    // MARK: - Helpers

    @MainActor
    private func makeConfig(host: String, port: Int = 8080) -> ConnectionConfig {
        ConnectionConfig(host: host, port: port, useTLS: false, basePath: "/", authToken: nil)
    }
}
