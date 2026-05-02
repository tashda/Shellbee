import XCTest
@testable import Shellbee

final class BridgeRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        UserDefaults.standard.removeObject(forKey: "savedBridges.defaultID")
        UserDefaults.standard.removeObject(forKey: "savedBridges.autoConnectIDs")
        MainActor.assumeIsolated { ConnectionConfig.clearPersistedSecretsForTests() }
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        UserDefaults.standard.removeObject(forKey: "savedBridges.defaultID")
        UserDefaults.standard.removeObject(forKey: "savedBridges.autoConnectIDs")
        MainActor.assumeIsolated { ConnectionConfig.clearPersistedSecretsForTests() }
        super.tearDown()
    }

    // MARK: - basic shape

    @MainActor
    func testEmptyRegistryHasNoPrimary() {
        let registry = BridgeRegistry(history: ConnectionHistory())
        XCTAssertNil(registry.primaryBridgeID)
        XCTAssertNil(registry.primary)
        XCTAssertTrue(registry.sessions.isEmpty)
    }

    @MainActor
    func testConnectCreatesSessionAndBecomesPrimary() {
        let history = ConnectionHistory()
        let registry = BridgeRegistry(history: history)
        let cfg = makeConfig(name: "Main")

        registry.connect(config: cfg)

        XCTAssertEqual(registry.sessions.count, 1)
        XCTAssertEqual(registry.primaryBridgeID, cfg.id)
        XCTAssertNotNil(registry.session(for: cfg.id))
    }

    @MainActor
    func testSecondConnectKeepsExistingSessionAndPrimary() {
        let history = ConnectionHistory()
        let registry = BridgeRegistry(history: history)
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

    @MainActor
    func testReConnectingSameBridgeReusesSession() {
        let history = ConnectionHistory()
        let registry = BridgeRegistry(history: history)
        let cfg = makeConfig(name: "Main")

        registry.connect(config: cfg)
        let firstSessionRef = registry.session(for: cfg.id)
        registry.connect(config: cfg)
        let secondSessionRef = registry.session(for: cfg.id)

        XCTAssertEqual(registry.sessions.count, 1)
        XCTAssertTrue(firstSessionRef === secondSessionRef)
    }

    @MainActor
    func testSetPrimaryNoOpForUnknownID() {
        let registry = BridgeRegistry(history: ConnectionHistory())
        let unknown = UUID()
        registry.setPrimary(unknown)
        XCTAssertNil(registry.primaryBridgeID)
    }

    @MainActor
    func testSetPrimarySwitchesFocus() {
        let registry = BridgeRegistry(history: ConnectionHistory())
        let first = makeConfig(name: "Main")
        let second = makeConfig(name: "Lab")
        registry.connect(config: first)
        registry.connect(config: second)

        registry.setPrimary(second.id)
        XCTAssertEqual(registry.primaryBridgeID, second.id)
    }

    @MainActor
    func testOrderedSessionsSortsByDisplayName() {
        let registry = BridgeRegistry(history: ConnectionHistory())
        registry.connect(config: makeConfig(name: "Zebra"))
        registry.connect(config: makeConfig(name: "Alpha"))
        registry.connect(config: makeConfig(name: "Mango"))

        let names = registry.orderedSessions.map(\.displayName)
        XCTAssertEqual(names, ["Alpha", "Mango", "Zebra"])
    }

    @MainActor
    func testDisconnectAllClearsRegistry() async {
        let registry = BridgeRegistry(history: ConnectionHistory())
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
