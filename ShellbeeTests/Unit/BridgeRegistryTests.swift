import XCTest
@testable import Shellbee

final class BridgeRegistryTests: MultiBridgeTestCase {

    // MARK: - basic shape

    func testEmptyRegistryHasNoPrimary() {
        let registry = makeRegistry(history: ConnectionHistory())
        XCTAssertNil(registry.primaryBridgeID)
        XCTAssertNil(registry.primary)
        XCTAssertTrue(registry.sessions.isEmpty)
    }

    func testConnectCreatesSessionAndBecomesPrimary() {
        let history = ConnectionHistory()
        let registry = makeRegistry(history: history)
        let cfg = makeConfig(name: "Main")

        registry.connect(config: cfg)

        XCTAssertEqual(registry.sessions.count, 1)
        XCTAssertEqual(registry.primaryBridgeID, cfg.id)
        XCTAssertNotNil(registry.session(for: cfg.id))
    }

    func testSecondConnectKeepsExistingSessionAndPrimary() {
        let history = ConnectionHistory()
        let registry = makeRegistry(history: history)
        let first = makeConfig(name: "Main")
        let second = makeConfig(name: "Lab")

        registry.connect(config: first)
        let originalPrimary = registry.primaryBridgeID
        registry.connect(config: second)

        XCTAssertEqual(registry.sessions.count, 2)
        // Adding a second bridge does NOT change focus — that's the explicit
        // multi-bridge contract: a new connection never disturbs the focused one.
        XCTAssertEqual(registry.primaryBridgeID, originalPrimary)
    }

    func testReConnectingSameBridgeReusesSession() {
        let history = ConnectionHistory()
        let registry = makeRegistry(history: history)
        let cfg = makeConfig(name: "Main")

        registry.connect(config: cfg)
        let firstSessionRef = registry.session(for: cfg.id)
        registry.connect(config: cfg)
        let secondSessionRef = registry.session(for: cfg.id)

        XCTAssertEqual(registry.sessions.count, 1)
        XCTAssertTrue(firstSessionRef === secondSessionRef)
    }

    func testSetPrimaryNoOpForUnknownID() {
        let registry = makeRegistry(history: ConnectionHistory())
        let unknown = UUID()
        registry.setPrimary(unknown)
        XCTAssertNil(registry.primaryBridgeID)
    }

    func testSetPrimarySwitchesFocus() {
        let registry = makeRegistry(history: ConnectionHistory())
        let first = makeConfig(name: "Main")
        let second = makeConfig(name: "Lab")
        registry.connect(config: first)
        registry.connect(config: second)

        registry.setPrimary(second.id)
        XCTAssertEqual(registry.primaryBridgeID, second.id)
    }

    func testOrderedSessionsSortsByDisplayName() {
        let registry = makeRegistry(history: ConnectionHistory())
        registry.connect(config: makeConfig(name: "Zebra"))
        registry.connect(config: makeConfig(name: "Alpha"))
        registry.connect(config: makeConfig(name: "Mango"))

        let names = registry.orderedSessions.map(\.displayName)
        XCTAssertEqual(names, ["Alpha", "Mango", "Zebra"])
    }

    func testDisconnectAllClearsRegistry() async {
        let registry = makeRegistry(history: ConnectionHistory())
        registry.connect(config: makeConfig(name: "A"))
        registry.connect(config: makeConfig(name: "B"))

        await registry.disconnectAll()

        XCTAssertTrue(registry.sessions.isEmpty)
        XCTAssertNil(registry.primaryBridgeID)
    }

    // MARK: - helpers

    private func makeConfig(name: String) -> ConnectionConfig {
        ConnectionConfig(
            id: UUID(),
            host: "\(name.lowercased()).local",
            port: 8080,
            useTLS: false,
            basePath: "/",
            authToken: nil,
            name: name
        )
    }
}
