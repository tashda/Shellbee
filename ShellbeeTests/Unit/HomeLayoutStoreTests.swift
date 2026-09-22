import XCTest
@testable import Shellbee

@MainActor
final class HomeLayoutStoreTests: XCTestCase {

    private static let keys = [
        "homeVisibleOrder",
        "homeHiddenCards",
        "homeLayoutInitialized",
        "homeMergedCardsMigrationV1",
    ]

    override func setUp() async throws {
        try await super.setUp()
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() async throws {
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try await super.tearDown()
    }

    // Behavior: on first launch Home shows all three cards in declaration
    // order, with nothing hidden. The initialization flag is written so
    // later launches don't re-derive the default set.
    func testFirstLaunchShowsEveryCard() {
        let store = HomeLayoutStore()
        XCTAssertTrue(store.hidden.isEmpty)
        XCTAssertEqual(store.visibleOrder, [.network, .devices, .activity])
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "homeLayoutInitialized"))
    }

    // Behavior: hide() moves a card from visibleOrder into the hidden
    // set, and the change is persisted across a fresh store instance.
    func testHidingACardPersists() {
        let store = HomeLayoutStore()
        store.hide(.devices)
        XCTAssertFalse(store.visibleOrder.contains(.devices))
        XCTAssertTrue(store.hidden.contains(.devices))

        let reloaded = HomeLayoutStore()
        XCTAssertFalse(reloaded.visibleOrder.contains(.devices))
        XCTAssertTrue(reloaded.hidden.contains(.devices))
    }

    // Behavior: show() removes a card from hidden and appends it to
    // visibleOrder (if not already present). This persists across reloads.
    func testShowingAHiddenCardAppendsIt() {
        let store = HomeLayoutStore()
        store.hide(.network)
        XCTAssertTrue(store.hidden.contains(.network))

        store.show(.network)
        XCTAssertFalse(store.hidden.contains(.network))
        XCTAssertEqual(store.visibleOrder.last, .network,
                       "Newly shown cards append to the end of visibleOrder")

        let reloaded = HomeLayoutStore()
        XCTAssertFalse(reloaded.hidden.contains(.network))
        XCTAssertTrue(reloaded.visibleOrder.contains(.network))
    }

    // Behavior: the IndexSet-based move() reorders visibleOrder in the
    // same way SwiftUI's List.onMove does, and the new order persists.
    func testMoveReordersAndPersists() {
        let store = HomeLayoutStore()
        // Current order: [network, devices, activity]
        store.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.visibleOrder, [.devices, .activity, .network])

        let reloaded = HomeLayoutStore()
        XCTAssertEqual(reloaded.visibleOrder, [.devices, .activity, .network])
    }

    // Behavior: move(_:before:) is a SwiftUI drop-target-style reorder.
    // Dropping a source ONTO a target earlier in the list pulls source
    // in front of target (source ends at target's index). Dropping onto
    // a target LATER than source drops source directly after target,
    // which matches drag-and-drop affinity (drop below a row = after it).
    func testMoveBeforeHandlesBothDirections() {
        let store = HomeLayoutStore()
        // [network, devices, activity]
        store.move(.activity, before: .network)
        XCTAssertEqual(store.visibleOrder, [.activity, .network, .devices],
                       "Dragging backward lands source at target's index")

        store.move(.activity, before: .devices)
        XCTAssertEqual(store.visibleOrder, [.network, .devices, .activity],
                       "Dragging forward onto a later target drops source after it")
    }

    // MARK: - Migration off the five-card layout

    // Behavior: a layout saved before Bridge/Mesh merged into Network and
    // Groups folded into Devices is rewritten in place. Both old ids
    // collapse onto Network without duplicating it, and the user's relative
    // order survives.
    func testLegacyOrderFoldsOntoTheMergedCards() {
        UserDefaults.standard.set("recentEvents,bridge,devices,mesh", forKey: "homeVisibleOrder")
        UserDefaults.standard.set(true, forKey: "homeLayoutInitialized")

        let store = HomeLayoutStore()
        XCTAssertEqual(store.visibleOrder, [.activity, .network, .devices],
                       "bridge and mesh both become network, deduped, order preserved")
        XCTAssertTrue(store.hidden.isEmpty)

        let reloaded = HomeLayoutStore()
        XCTAssertEqual(reloaded.visibleOrder, [.activity, .network, .devices],
                       "the folded order is written back, not re-derived every launch")
    }

    // Behavior: Groups shipped hidden by default. Since Groups folded into
    // Devices, that hidden entry must be dropped — hiding a card the user
    // never chose to hide would silently remove their devices from Home.
    func testHiddenGroupsDoesNotHideDevices() {
        UserDefaults.standard.set("bridge,devices,mesh,recentEvents", forKey: "homeVisibleOrder")
        UserDefaults.standard.set("groups", forKey: "homeHiddenCards")
        UserDefaults.standard.set(true, forKey: "homeLayoutInitialized")

        let store = HomeLayoutStore()
        XCTAssertTrue(store.hidden.isEmpty)
        XCTAssertTrue(store.visibleOrder.contains(.devices))
    }

    // Behavior: a card the user deliberately hid stays hidden through the
    // migration.
    func testDeliberatelyHiddenCardSurvivesMigration() {
        UserDefaults.standard.set("bridge,devices,mesh", forKey: "homeVisibleOrder")
        UserDefaults.standard.set("recentEvents", forKey: "homeHiddenCards")
        UserDefaults.standard.set(true, forKey: "homeLayoutInitialized")

        let store = HomeLayoutStore()
        XCTAssertTrue(store.hidden.contains(.activity))
        XCTAssertFalse(store.visibleOrder.contains(.activity))
    }
}
