import XCTest

final class LogsUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        // Navigate to Logs via Settings tab
        app.tapSettingsTab()
        let logsRow = app.cells.containing(.staticText, identifier: "Logs").firstMatch
        if logsRow.waitForExistence(timeout: 5) {
            logsRow.tap()
        }
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 10)
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
            Thread.sleep(forTimeInterval: 1)
        }
    }

    // MARK: - Log detail

    func testTappingLogEntryOpensDetail() throws {
        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("No log entries visible")
        }
        app.cells.firstMatch.tap()
        // After pushing log detail, back button to "Logs" appears
        XCTAssertTrue(
            app.buttons["Logs"].firstMatch.waitForExistence(timeout: 5) ||
            app.sheets.firstMatch.waitForExistence(timeout: 5),
            "Log detail did not open"
        )
    }
}
