import XCTest
@testable import Shellbee

/// Phase 1 multi-bridge: lock down that detail-screen navigation routes by
/// `bridgeID` rather than by the focused-bridge shim. These tests exercise
/// the routing primitives (`scope(for:)`, `BridgeBoundDevice`, route values)
/// that the new view layer depends on. UI-level integration is covered by
/// the manual smoke testing playbook in CLAUDE.md.
final class MultiBridgeNavigationTests: MultiBridgeTestCase {

    // MARK: - Detail routing reads from passed bridgeID, not focus

    @MainActor
    func testScopeForNonFocusedBridgeReadsCorrectStore() {
        let env = makeEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        // Different friendly-named devices on each bridge so name lookup
        // alone wouldn't be sufficient — the test is meaningful only when
        // bridgeID-based routing is used.
        let scopeA = env.scope(for: a.id)
        let scopeB = env.scope(for: b.id)
        scopeA.store.devices = [makeDevice(name: "Alpha", ieee: "0xA1")]
        scopeB.store.devices = [makeDevice(name: "Bravo", ieee: "0xB1")]

        // Focus is on A (first-connected default).
        XCTAssertEqual(env.registry.primaryBridgeID, a.id)

        // A detail scoped to B reads B's store regardless of focus.
        let bDevice = env.scope(for: b.id).store.devices.first!
        XCTAssertEqual(bDevice.friendlyName, "Bravo",
                       "Detail scope should read from its own bridge, not the focused one")

        // The same name "Bravo" doesn't exist on A — proves there's no
        // accidental fallthrough.
        XCTAssertNil(env.scope(for: a.id).store.device(named: "Bravo"))
    }

    // MARK: - Name-collision routing across bridges

    @MainActor
    func testSameDeviceNameOnTwoBridgesResolvesByBridgeID() {
        let env = makeEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        // Same friendly name on both bridges, distinct IEEEs. This is the
        // exact scenario the deprecated `bridge(forDevice:)` lookup gets
        // wrong (it returns first-match). Bridge id is the only correct key.
        let scopeA = env.scope(for: a.id)
        let scopeB = env.scope(for: b.id)
        scopeA.store.devices = [makeDevice(name: "Living Room", ieee: "0xAAAA")]
        scopeB.store.devices = [makeDevice(name: "Living Room", ieee: "0xBBBB")]

        let routeA = DeviceRoute(bridgeID: a.id, device: scopeA.store.devices[0])
        let routeB = DeviceRoute(bridgeID: b.id, device: scopeB.store.devices[0])

        XCTAssertNotEqual(routeA, routeB,
                          "Routes must be distinguishable when names collide")
        XCTAssertNotEqual(env.scope(for: routeA.bridgeID).store.devices[0].ieeeAddress,
                          env.scope(for: routeB.bridgeID).store.devices[0].ieeeAddress)
    }

    // MARK: - Device action mutates only the routed bridge

    @MainActor
    func testIdentifyOnRoutedBridgeDoesNotLeakAcross() {
        let env = makeEnvironment()
        let a = makeConfig(name: "A")
        let b = makeConfig(name: "B")
        env.connect(config: a)
        env.connect(config: b)

        let scopeA = env.scope(for: a.id)
        let scopeB = env.scope(for: b.id)
        scopeA.store.devices = [makeDevice(name: "Lamp", ieee: "0xA1")]
        scopeB.store.devices = [makeDevice(name: "Lamp", ieee: "0xB1")]

        // Identify "Lamp" on bridge B.
        scopeB.identifyDevice("Lamp")

        XCTAssertTrue(scopeB.store.identifyInProgress.contains("Lamp"))
        XCTAssertFalse(scopeA.store.identifyInProgress.contains("Lamp"),
                       "Routed identify must not write to bridge A's identify set")
    }

    // MARK: - DeviceRoute carries provenance through Hashable identity

    @MainActor
    func testDeviceRouteHashableUsesBothBridgeIDAndDevice() {
        let bridgeA = UUID()
        let bridgeB = UUID()
        let device = makeDevice(name: "Sensor", ieee: "0xC1")
        let r1 = DeviceRoute(bridgeID: bridgeA, device: device)
        let r2 = DeviceRoute(bridgeID: bridgeA, device: device)
        let r3 = DeviceRoute(bridgeID: bridgeB, device: device)
        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3,
                          "Same device on different bridges is a different route")

        var set: Set<DeviceRoute> = []
        set.insert(r1)
        set.insert(r3)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - GroupRoute disambiguates colliding group ids across bridges

    @MainActor
    func testGroupRouteHashableUsesBothBridgeIDAndGroup() {
        let bridgeA = UUID()
        let bridgeB = UUID()
        // Same numeric group id on two bridges — z2m allows this since group
        // ids are scoped per Z2M instance.
        let group = Group(id: 42, friendlyName: "Living", members: [], scenes: [])
        let r1 = GroupRoute(bridgeID: bridgeA, group: group)
        let r2 = GroupRoute(bridgeID: bridgeB, group: group)
        XCTAssertNotEqual(r1, r2)
    }

    // MARK: - Helpers

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

    private func makeDevice(name: String, ieee: String) -> Device {
        Device(
            ieeeAddress: ieee,
            type: .endDevice,
            networkAddress: 1,
            supported: true,
            friendlyName: name,
            disabled: false,
            definition: nil,
            powerSource: nil,
            interviewCompleted: true,
            interviewing: false
        )
    }
}
