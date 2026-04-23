import XCTest
@testable import Shellbee

@MainActor
final class NotificationCoalescingTests: XCTestCase {

    var store: AppStore!

    override func setUp() {
        super.setUp()
        store = AppStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testDistinctTitlesEnqueueSeparately() {
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", category: .operationFailed))
        store.enqueueNotification(.init(level: .error, title: "Bind Failed", category: .bindFailure))
        XCTAssertEqual(store.pendingNotifications.count, 2)
    }

    func testSameTitleCoalescesWithinWindow() {
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", subtitle: "a", category: .operationFailed))
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", subtitle: "b", category: .operationFailed))
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", subtitle: "c", category: .operationFailed))
        XCTAssertEqual(store.pendingNotifications.count, 1)
        XCTAssertEqual(store.pendingNotifications.first?.count, 3)
        XCTAssertEqual(store.pendingNotifications.first?.subtitle, "c", "subtitle should reflect the most recent")
    }

    func testCoalescesIntoCurrentlyVisibleNotification() {
        let first = InAppNotification(level: .error, title: "Operation Failed", category: .operationFailed)
        store.pendingNotifications.append(first)
        let popped = store.popNotification()
        store.currentNotification = popped

        store.enqueueNotification(.init(level: .error, title: "Operation Failed", category: .operationFailed))
        XCTAssertEqual(store.currentNotification?.count, 2)
        XCTAssertEqual(store.pendingNotifications.count, 0, "should not spawn a new queued entry when one is visible")
    }

    func testLogEntryIDsAggregate() {
        let id1 = UUID()
        let id2 = UUID()
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", logEntryID: id1, category: .operationFailed))
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", logEntryID: id2, category: .operationFailed))
        XCTAssertEqual(store.pendingNotifications.first?.logEntryIDs, [id1, id2])
    }

    func testFastTrackDoesNotCoalesce() {
        store.enqueueNotification(.init(level: .info, title: "Copied to Clipboard", priority: .fastTrack))
        store.enqueueNotification(.init(level: .info, title: "Copied to Clipboard", priority: .fastTrack))
        XCTAssertEqual(store.fastTrackNotifications.count, 2)
        XCTAssertEqual(store.pendingNotifications.count, 0)
    }

    func testFilterDropsNotification() {
        store.notificationFilter = { $0.category != .otaNoUpdate }
        store.enqueueNotification(.init(level: .info, title: "No Update Available", category: .otaNoUpdate))
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", category: .operationFailed))
        XCTAssertEqual(store.pendingNotifications.count, 1)
        XCTAssertEqual(store.pendingNotifications.first?.category, .operationFailed)
    }

    func testFilterDoesNotBlockFastTrack() {
        store.notificationFilter = { _ in false }
        store.enqueueNotification(.init(level: .info, title: "Copied to Clipboard", priority: .fastTrack))
        XCTAssertEqual(store.fastTrackNotifications.count, 1)
    }
}
