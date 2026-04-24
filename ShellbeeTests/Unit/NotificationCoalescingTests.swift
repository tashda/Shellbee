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
        XCTAssertEqual(store.pendingNotifications.first?.occurrences.map(\.subtitle), ["a", "b", "c"])
    }

    func testArrivalIDBumpsOnlyForNewBanners() {
        let before = store.notificationArrivalID
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", category: .operationFailed))
        let afterFirst = store.notificationArrivalID
        XCTAssertNotEqual(before, afterFirst)

        // Coalescing should NOT bump the arrival ID.
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", category: .operationFailed))
        XCTAssertEqual(store.notificationArrivalID, afterFirst)

        // A distinct banner bumps again.
        store.enqueueNotification(.init(level: .warning, title: "Device Left Network", category: .deviceLeft))
        XCTAssertNotEqual(store.notificationArrivalID, afterFirst)
    }

    func testLogEntryIDsAggregate() {
        let id1 = UUID()
        let id2 = UUID()
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", logEntryID: id1, category: .operationFailed))
        store.enqueueNotification(.init(level: .error, title: "Operation Failed", logEntryID: id2, category: .operationFailed))
        XCTAssertEqual(store.pendingNotifications.first?.logEntryIDs, [id1, id2])
        XCTAssertEqual(store.pendingNotifications.first?.occurrences.flatMap(\.logEntryIDs), [id1, id2])
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

    // Behavior: when multiple OTA progress notifications arrive for
    // different devices under the same title, each becomes a separate
    // occurrence on the coalesced banner. The overlay's carousel uses
    // `occurrences` to page through device-specific subtitles and log
    // references; duplicated log IDs would cause the detail sheet to
    // open the wrong entry.
    func testOTAOccurrencesTrackDistinctDeviceEntries() {
        let kitchenLog = UUID()
        let bedroomLog = UUID()

        store.enqueueNotification(.init(
            level: .info,
            title: "OTA update finished",
            subtitle: "Kitchen Plug",
            logEntryID: kitchenLog,
            deviceName: "Kitchen Plug",
            category: .otaUpdateInstalled
        ))
        store.enqueueNotification(.init(
            level: .info,
            title: "OTA update finished",
            subtitle: "Bedroom Hue",
            logEntryID: bedroomLog,
            deviceName: "Bedroom Hue",
            category: .otaUpdateInstalled
        ))

        XCTAssertEqual(store.pendingNotifications.count, 1, "Same title should coalesce")
        let notif = store.pendingNotifications.first!
        XCTAssertEqual(notif.count, 2)
        XCTAssertEqual(notif.occurrences.map(\.deviceName), ["Kitchen Plug", "Bedroom Hue"])
        XCTAssertEqual(notif.occurrences.map(\.subtitle), ["Kitchen Plug", "Bedroom Hue"])
        XCTAssertEqual(notif.occurrences.flatMap(\.logEntryIDs), [kitchenLog, bedroomLog])
        XCTAssertEqual(notif.logEntryIDs, [kitchenLog, bedroomLog])
    }

    // Behavior: the `displaying(occurrence:)` helper returns a copy of
    // the coalesced notification with the given occurrence's subtitle
    // and deviceName, leaving the aggregated count/ID and log ID list
    // intact. The overlay uses this when swiping through pages.
    func testDisplayingOccurrenceSwapsSubtitleAndDevice() {
        store.enqueueNotification(.init(
            level: .info, title: "OTA update finished",
            subtitle: "Kitchen Plug", deviceName: "Kitchen Plug",
            category: .otaUpdateInstalled
        ))
        store.enqueueNotification(.init(
            level: .info, title: "OTA update finished",
            subtitle: "Bedroom Hue", deviceName: "Bedroom Hue",
            category: .otaUpdateInstalled
        ))

        let banner = store.pendingNotifications.first!
        let viewingFirst = banner.displaying(banner.occurrences[0])
        XCTAssertEqual(viewingFirst.subtitle, "Kitchen Plug")
        XCTAssertEqual(viewingFirst.deviceName, "Kitchen Plug")
        XCTAssertEqual(viewingFirst.count, 2,
                       "Occurrence display should keep the aggregated count")

        let viewingSecond = banner.displaying(banner.occurrences[1])
        XCTAssertEqual(viewingSecond.subtitle, "Bedroom Hue")
        XCTAssertEqual(viewingSecond.deviceName, "Bedroom Hue")
    }
}
