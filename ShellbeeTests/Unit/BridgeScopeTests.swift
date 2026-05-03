import XCTest
@testable import Shellbee

/// Phase 0 of the multi-bridge migration: verify that `BridgeScope` is the
/// canonical, non-leaky way to address one specific bridge. The legacy
/// focused-bridge shims on `AppEnvironment` are deprecated; these tests lock
/// down the replacement so subsequent migration phases have a stable contract.
final class BridgeScopeTests: XCTestCase {

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

    // MARK: - resolution

    @MainActor
    func testScopeForUnknownIDReturnsNil() {
        let env = AppEnvironment()
        XCTAssertNil(env.scope(for: UUID()))
    }

    @MainActor
    func testScopeForKnownIDResolvesToThatSession() {
        let env = AppEnvironment()
        let cfg = makeConfig(name: "Main")
        env.connect(config: cfg)

        let scope = env.scope(for: cfg.id)
        XCTAssertNotNil(scope)
        XCTAssertEqual(scope?.bridgeID, cfg.id)
        XCTAssertTrue(scope?.session === env.registry.session(for: cfg.id))
    }

    @MainActor
    func testSelectedScopeFollowsRegistryPrimary() {
        let env = AppEnvironment()
        let first = makeConfig(name: "Main")
        let second = makeConfig(name: "Lab")
        env.connect(config: first)
        env.connect(config: second)

        XCTAssertEqual(env.selectedScope?.bridgeID, first.id, "First connect becomes primary")

        env.registry.setPrimary(second.id)
        XCTAssertEqual(env.selectedScope?.bridgeID, second.id)
    }

    @MainActor
    func testSelectedScopeNilWhenNoBridges() {
        let env = AppEnvironment()
        XCTAssertNil(env.selectedScope)
    }

    // MARK: - bridge isolation

    @MainActor
    func testEachScopeReadsFromItsOwnStore() {
        let env = AppEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        let scopeA = env.scope(for: a.id)!
        let scopeB = env.scope(for: b.id)!

        XCTAssertFalse(scopeA.store === scopeB.store, "Different bridges must own separate stores")
    }

    @MainActor
    func testIdentifyDeviceMutatesScopedStoreOnly() {
        let env = AppEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        let scopeA = env.scope(for: a.id)!
        let scopeB = env.scope(for: b.id)!

        scopeA.identifyDevice("Lamp")

        XCTAssertTrue(scopeA.store.identifyInProgress.contains("Lamp"))
        XCTAssertFalse(scopeB.store.identifyInProgress.contains("Lamp"),
                       "Identify on bridge A must not leak into bridge B's store")
    }

    @MainActor
    func testIdentifyDeviceDeDupesPerBridge() {
        let env = AppEnvironment()
        let cfg = makeConfig(name: "Main")
        env.connect(config: cfg)
        let scope = env.scope(for: cfg.id)!

        scope.identifyDevice("Lamp")
        let firstSize = scope.store.identifyInProgress.count
        scope.identifyDevice("Lamp")
        XCTAssertEqual(scope.store.identifyInProgress.count, firstSize,
                       "Repeat identify while in progress is a no-op")
    }

    @MainActor
    func testRenameDeviceTriggersOptimisticRenameInScopedStoreOnly() {
        let env = AppEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        let scopeA = env.scope(for: a.id)!
        let scopeB = env.scope(for: b.id)!

        scopeA.store.devices = [
            Device(ieeeAddress: "0x1", type: .endDevice, networkAddress: 1, supported: true,
                   friendlyName: "Old", disabled: false, definition: nil, powerSource: nil,
                   interviewCompleted: true, interviewing: false)
        ]
        scopeB.store.devices = [
            Device(ieeeAddress: "0x2", type: .endDevice, networkAddress: 2, supported: true,
                   friendlyName: "Old", disabled: false, definition: nil, powerSource: nil,
                   interviewCompleted: true, interviewing: false)
        ]

        scopeA.renameDevice(from: "Old", to: "New", homeassistantRename: false)

        XCTAssertEqual(scopeA.store.devices.first?.friendlyName, "New",
                       "Rename on scope A renames in A's store")
        XCTAssertEqual(scopeB.store.devices.first?.friendlyName, "Old",
                       "Rename on scope A must not touch B's store")
    }

    // MARK: - scope identity

    @MainActor
    func testScopeIDEqualsBridgeID() {
        let env = AppEnvironment()
        let cfg = makeConfig(name: "Main")
        env.connect(config: cfg)
        let scope = env.scope(for: cfg.id)!
        XCTAssertEqual(scope.id, cfg.id)
    }

    @MainActor
    func testScopeIsConnectedReflectsSessionState() {
        let env = AppEnvironment()
        let cfg = makeConfig(name: "Main")
        env.connect(config: cfg)
        let scope = env.scope(for: cfg.id)!
        // Newly connected — controller hasn't reached `.connected` against a
        // real WebSocket in the test harness, so isConnected may be false.
        // Important property here is that the scope reads the live session
        // value, not a cached one.
        XCTAssertEqual(scope.isConnected, scope.session.isConnected)
        XCTAssertEqual(scope.connectionState, scope.session.connectionState)
    }

    // MARK: - per-bridge OTA queues

    @MainActor
    func testOTABulkQueueForReturnsDistinctQueuesPerBridge() {
        let env = AppEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        let queueA = env.otaBulkQueue(for: a.id)
        let queueB = env.otaBulkQueue(for: b.id)

        XCTAssertNotNil(queueA)
        XCTAssertNotNil(queueB)
        XCTAssertFalse(queueA === queueB, "Each bridge gets its own OTA queue")
    }

    @MainActor
    func testOTABulkQueueForUnknownBridgeReturnsNil() {
        let env = AppEnvironment()
        XCTAssertNil(env.otaBulkQueue(for: UUID()))
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
