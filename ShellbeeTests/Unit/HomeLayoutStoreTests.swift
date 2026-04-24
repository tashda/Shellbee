import XCTest
@testable import Shellbee

@MainActor
final class HomeLayoutStoreTests: XCTestCase {

    private static let keys = [
        "homeVisibleOrder",
        "homeHiddenCards",
        "homeLayoutInitialized",
    ]

    override func setUp() async throws {
        try await super.setUp()
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() async throws {
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        try await super.tearDown()
    }

    // Behavior: on first launch the Home layout initializes with all
    // cards visible EXCEPT Groups, which is hidden by default. The
    // initialization flag is written to defaults so subsequent launches
    // don't re-apply the default-hidden set.
    func testFirstLaunchHidesGroupsByDefault() {
        let store = HomeLayoutStore()
        XCTAssertEqual(store.hidden, [HomeCardID.groups])
        XCTAssertEqual(store.visibleOrder, [.bridge, .devices, .mesh, .recentEvents])
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
        XCTAssertTrue(store.hidden.contains(.groups))

        store.show(.groups)
        XCTAssertFalse(store.hidden.contains(.groups))
        XCTAssertEqual(store.visibleOrder.last, .groups,
                       "Newly shown cards append to the end of visibleOrder")

        let reloaded = HomeLayoutStore()
        XCTAssertFalse(reloaded.hidden.contains(.groups))
        XCTAssertTrue(reloaded.visibleOrder.contains(.groups))
    }

    // Behavior: the IndexSet-based move() reorders visibleOrder in the
    // same way SwiftUI's List.onMove does, and the new order persists.
    func testMoveReordersAndPersists() {
        let store = HomeLayoutStore()
        // Current order: [bridge, devices, mesh, recentEvents]
        store.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.visibleOrder, [.devices, .mesh, .bridge, .recentEvents])

        let reloaded = HomeLayoutStore()
        XCTAssertEqual(reloaded.visibleOrder, [.devices, .mesh, .bridge, .recentEvents])
    }

    // Behavior: move(_:before:) is a SwiftUI drop-target-style reorder.
    // Dropping a source ONTO a target earlier in the list pulls source
    // in front of target (source ends at target's index). Dropping onto
    // a target LATER than source drops source directly after target,
    // which matches drag-and-drop affinity (drop below a row = after it).
    func testMoveBeforeHandlesBothDirections() {
        let store = HomeLayoutStore()
        // [bridge, devices, mesh, recentEvents]
        store.move(.recentEvents, before: .bridge)
        XCTAssertEqual(store.visibleOrder, [.recentEvents, .bridge, .devices, .mesh],
                       "Dragging backward lands source at target's index")

        store.move(.recentEvents, before: .mesh)
        XCTAssertEqual(store.visibleOrder, [.bridge, .devices, .mesh, .recentEvents],
                       "Dragging forward onto a later target drops source after it")
    }

    // Behavior: after the default-hidden set has been applied once,
    // subsequent launches that encounter a Groups card freshly moved
    // into visibleOrder should NOT re-hide it. The initializedKey flag
    // prevents the default-hidden logic from running twice.
    func testDefaultHiddenOnlyAppliesOnce() {
        _ = HomeLayoutStore()
        let store = HomeLayoutStore()
        store.show(.groups)
        let reloaded = HomeLayoutStore()
        XCTAssertFalse(reloaded.hidden.contains(.groups))
        XCTAssertTrue(reloaded.visibleOrder.contains(.groups))
    }
}
