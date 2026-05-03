import XCTest
@testable import Shellbee

@MainActor
final class ConnectionHistoryTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        ConnectionConfig.clearPersistedSecretsForTests()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        ConnectionConfig.clearPersistedSecretsForTests()
        try await super.tearDown()
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
    func testAddKeepsHTTPAndHTTPSEntriesDistinct() {
        let h = ConnectionHistory()
        h.add(makeConfig(host: "host", port: 8080, useTLS: false))
        h.add(makeConfig(host: "host", port: 8080, useTLS: true))
        XCTAssertEqual(h.connections.count, 2)
        XCTAssertEqual(h.connections.first?.useTLS, true)
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

    @MainActor
    func testRemoveAtOffsetsRemovesPersistedToken() {
        let h = ConnectionHistory()
        h.add(ConnectionConfig(host: "token.host", port: 8080, useTLS: false, basePath: "/", authToken: "secret"))

        h.remove(at: IndexSet(integer: 0))

        let reloaded = ConnectionHistory()
        XCTAssertTrue(reloaded.connections.isEmpty)
        XCTAssertNil(
            ConnectionConfig.PersistedSnapshot(host: "token.host", port: 8080, useTLS: false, basePath: "/")
                .connectionConfig
                .authToken
        )
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

    @MainActor
    func testHistoryLoadsTokenFromKeychain() {
        let h1 = ConnectionHistory()
        h1.add(ConnectionConfig(host: "persistent", port: 8080, useTLS: false, basePath: "/", authToken: "secret"))

        let h2 = ConnectionHistory()
        XCTAssertEqual(h2.connections.first?.authToken, "secret")
    }

    @MainActor
    func testHistoryMigratesLegacyEntriesToKeychain() throws {
        let legacy = [
            ConnectionConfig(host: "legacy", port: 8080, useTLS: false, basePath: "/", authToken: "legacy-secret")
        ]
        let data = try JSONEncoder().encode(legacy)
        UserDefaults.standard.set(data, forKey: "connectionHistory")

        let history = ConnectionHistory()
        XCTAssertEqual(history.connections.first?.authToken, "legacy-secret")

        let migratedData = try XCTUnwrap(UserDefaults.standard.data(forKey: "connectionHistory"))
        let json = try JSONSerialization.jsonObject(with: migratedData) as? [[String: Any]]

        XCTAssertNil(json?.first?["authToken"])
        XCTAssertNil(json?.first?["auth_token"])
    }

    // MARK: - Helpers

    @MainActor
    private func makeConfig(host: String, port: Int = 8080, useTLS: Bool = false) -> ConnectionConfig {
        ConnectionConfig(host: host, port: port, useTLS: useTLS, basePath: "/", authToken: nil)
    }
}
