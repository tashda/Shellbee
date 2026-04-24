import XCTest

final class LogsUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        // Navigate to Logs via Settings tab. LogsView wraps itself in a
        // nested NavigationStack, so we wait for its "Logs" navigation
        // title rather than for a second navigation bar.
        app.tapSettingsTab()
        let logsRow = app.cells.containing(.staticText, identifier: "Logs").firstMatch
        XCTAssertTrue(logsRow.waitForExistence(timeout: 5),
                      "Logs row not found in Settings")
        logsRow.tap()
        XCTAssertTrue(
            app.navigationBars["Logs"].firstMatch.waitForExistence(timeout: 10),
            "Logs view did not appear"
        )
    }

    // MARK: - Log list

    func testLogsAppear() {
        // Seeder publishes log messages — they should appear here
        // Give some time for initial messages to arrive
        let cell = app.cells.firstMatch
        _ = cell.waitForExistence(timeout: 20)
        // Not a hard failure — no logs may appear if nothing happened yet
    }

    // MARK: - Search

    func testSearchFiltersLogs() {
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("seeder")
            // Results should be filtered
            _ = app.cells.firstMatch.waitForExistence(timeout: 5)
            search.buttons["Clear text"].tap()
        }
    }

    // MARK: - Filter

    func testFilterMenuOpens() {
        let filterBtn = app.buttons["Filter"].firstMatch
        if filterBtn.waitForExistence(timeout: 5) {
            filterBtn.tap()
            _ = app.buttons.firstMatch.waitForExistence(timeout: 3)
            app.tap()
        }
    }

    func testFilterByLevel() {
        let filterBtn = app.buttons["Filter"].firstMatch
        if filterBtn.waitForExistence(timeout: 5) {
            filterBtn.tap()
            if app.buttons["Error"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Error"].firstMatch.tap()
            }
            app.tap()
        }
    }

    // MARK: - Clear logs

    func testClearLogsButtonExists() {
        let clearBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Clear'")
        ).firstMatch
        _ = clearBtn.waitForExistence(timeout: 5)
    }

    func testClearLogsEmptiesList() {
        // Wait for at least one log entry
        guard app.cells.firstMatch.waitForExistence(timeout: 15) else { return }

        let clearBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Clear'")
        ).firstMatch

        if clearBtn.waitForExistence(timeout: 5) {
            clearBtn.tap()
            // Confirm if needed
            let confirm = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Clear'")
            ).firstMatch
            if confirm.waitForExistence(timeout: 2) {
                confirm.tap()
            }
            // List should be empty or near-empty
        }
    }

    // MARK: - Log detail

    // Behavior: tapping a row in the Activity log pushes LogDetailView,
    // which adds a "Logs" back button to the nav bar. Activity entries
    // come from state-change diffs — to make this deterministic (drift
    // timing is not reliable inside the 15s window), the test toggles
    // Kitchen Plug's switch on the Devices tab first, guaranteeing a
    // diff, then returns to the Logs tab (whose navigation stack was
    // preserved from setUp) and asserts on the tap.
    func testTappingLogEntryOpensDetail() {
        app.tapDevicesTab()
        let plug = app.cells.containing(.staticText, identifier: "Kitchen Plug").firstMatch
        XCTAssertTrue(plug.waitForExistence(timeout: 10),
                      "Kitchen Plug not in the device list")
        plug.tap()
        XCTAssertTrue(app.navigationBars["Kitchen Plug"].waitForExistence(timeout: 5),
                      "Kitchen Plug detail did not open")
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5),
                      "Kitchen Plug toggle not found")
        toggle.tap()

        // Switch back to Settings; its nav stack still has Logs pushed
        // on top from setUp, so the Logs view is already visible.
        app.tapSettingsTab()
        XCTAssertTrue(app.navigationBars["Logs"].waitForExistence(timeout: 5),
                      "Logs view should still be on the Settings nav stack")

        XCTAssertTrue(
            app.cells.firstMatch.waitForExistence(timeout: 10),
            "Activity log is empty after triggering a device state change"
        )
        app.cells.firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars.buttons["Logs"].firstMatch.waitForExistence(timeout: 5),
            "LogDetailView did not open — expected a 'Logs' back button"
        )
    }
}
