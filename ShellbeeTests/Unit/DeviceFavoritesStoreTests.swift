import XCTest
@testable import Shellbee

@MainActor
final class DeviceFavoritesStoreTests: XCTestCase {
    func testFavoritesPersistAndKeepBridgeIdentity() throws {
        let context = makeDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let bridgeID = UUID()
        let store = DeviceFavoritesStore(defaults: context.defaults)

        XCTAssertTrue(store.add(payload(name: "Lamp", ieee: "0x01", bridgeID: bridgeID)))
        let reloaded = DeviceFavoritesStore(defaults: context.defaults)

        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.bridgeID, bridgeID)
        XCTAssertEqual(reloaded.items.first?.ieeeAddress, "0x01")
    }

    func testDuplicateFavoriteIsIgnored() {
        let context = makeDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let store = DeviceFavoritesStore(defaults: context.defaults)
        let item = payload(name: "Lamp", ieee: "0x01", bridgeID: UUID())

        XCTAssertTrue(store.add(item))
        XCTAssertFalse(store.add(item))
        XCTAssertEqual(store.items.count, 1)
    }

    func testSameIEEEOnDifferentBridgesCreatesDistinctFavorites() {
        let context = makeDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let store = DeviceFavoritesStore(defaults: context.defaults)

        XCTAssertTrue(store.add(payload(name: "Lamp", ieee: "0x01", bridgeID: UUID())))
        XCTAssertTrue(store.add(payload(name: "Lamp", ieee: "0x01", bridgeID: UUID())))
        XCTAssertEqual(store.items.count, 2)
    }

    func testReorderingPersists() {
        let context = makeDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let store = DeviceFavoritesStore(defaults: context.defaults)
        let bridgeID = UUID()
        store.add(payload(name: "One", ieee: "0x01", bridgeID: bridgeID))
        store.add(payload(name: "Two", ieee: "0x02", bridgeID: bridgeID))
        store.add(payload(name: "Three", ieee: "0x03", bridgeID: bridgeID))

        store.move(id: store.items[2].id, offset: -1)

        XCTAssertEqual(store.items.map(\.friendlyName), ["One", "Three", "Two"])
        XCTAssertEqual(
            DeviceFavoritesStore(defaults: context.defaults).items.map(\.friendlyName),
            ["One", "Three", "Two"]
        )
    }

    func testPayloadWithoutBridgeCannotBecomeFavorite() {
        let context = makeDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let store = DeviceFavoritesStore(defaults: context.defaults)

        XCTAssertFalse(store.add(payload(name: "Lamp", ieee: "0x01", bridgeID: nil)))
        XCTAssertTrue(store.items.isEmpty)
    }

    private func makeDefaults() -> (defaults: UserDefaults, suite: String) {
        let suite = "DeviceFavoritesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    private func payload(
        name: String,
        ieee: String,
        bridgeID: UUID?
    ) -> DeviceTransferPayload {
        let device = Device(
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
        return DeviceTransferPayload(device: device, bridgeID: bridgeID, bridgeName: "Home")
    }
}
