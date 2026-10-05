import XCTest

/// The Activity feed on iPhone, opened from Home's Activity card. The card
/// is opt-in, so the suite turns it on at launch.
final class ActivityUITests: ShellbeeUITestCase {

    override func configureAppBeforeLaunch() {
        app.launchArguments += ["-homeCard.activity.enabled", "YES"]
    }

    override func setUp() {
        super.setUp()
        app.tapHomeTab()
        let seeAll = app.buttons["See all"].firstMatch
        seeAll.scrollIntoView(in: app)
        seeAll.tap()
        // A tap right after scrolling can land while the list is settling.
        if !app.navigationBars["Activity"].waitForExistence(timeout: 5) { seeAll.tap() }
        app.navigationBars["Activity"].assertExists(timeout: 10)
    }

    /// The mock bridge drifts device state on connect, so the feed has
    /// change events ("Battery: 73% → 72%") to show.
    func testFeedShowsDeviceChanges() {
        events.firstMatch.assertExists(timeout: 20)
    }

    func testModeSwitchesToTheRawLog() {
        app.activityModePicker.tapWhenReady(timeout: 5)
        app.buttons["Log"].firstMatch.tapWhenReady(timeout: 5)
        XCTAssertFalse(events.firstMatch.waitForExistence(timeout: 2),
                       "Activity cards are still showing in Log mode")

        app.activityModePicker.tapWhenReady(timeout: 5)
        app.buttons["Activity"].firstMatch.tapWhenReady(timeout: 5)
        events.firstMatch.assertExists(timeout: 10)
    }

    /// Cards update in place ("2 more updates", "now"), so they're
    /// compared by count, not by label. Clearing leaves at most the
    /// events that arrive afterwards.
    func testClearEmptiesTheFeed() {
        events.firstMatch.assertExists(timeout: 20)
        let before = events.count

        trashButton.tapWhenReady(timeout: 5)
        let alert = app.alerts["Clear Activity?"]
        alert.assertExists(timeout: 5)
        alert.buttons["Clear"].tap()

        XCTAssertLessThan(events.count, before, "Clear didn't remove the events that were showing")
    }

    func testCancellingClearKeepsEvents() {
        events.firstMatch.assertExists(timeout: 20)

        trashButton.tapWhenReady(timeout: 5)
        app.alerts["Clear Activity?"].buttons["Cancel"].tapWhenReady(timeout: 5)
        XCTAssertTrue(events.firstMatch.exists, "Cancelling Clear removed events")
    }

    // MARK: - Helpers

    /// Activity cards read as "<device>, <change>" with an arrow between
    /// the old and new value.
    private var trashButton: XCUIElement {
        app.navigationBars.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "trash", "Delete"))
            .firstMatch
    }

    private var events: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "→"))
    }
}

/// With Activity Center off there is no tab-bar accessory, and Settings
/// offers a Logs row that opens the same feed.
final class ActivityCenterDisabledUITests: ShellbeeUITestCase {

    override func configureAppBeforeLaunch() {
        app.launchArguments += ["-activityCenterEnabled", "NO"]
    }

    func testSettingsLogsRowOpensTheFeed() {
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Activity:")).firstMatch.exists,
            "The Activity accessory is still showing with Activity Center off"
        )
        app.tapSettingsTab()
        let logsRow = app.visibleCell(containing: "Logs")
        logsRow.scrollIntoView(in: app)
        logsRow.tap()
        app.activityModePicker.assertExists(timeout: 10)
    }
}
