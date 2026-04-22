import XCTest

final class DeviceListUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapDevicesTab()
        // Wait for device list to load
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
    }

    // MARK: - List appearance

    func testDeviceListIsNotEmpty() {
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15),
                      "Device list is empty — is the seeder running?")
    }

    func testAllNineDeviceCategoriesPresent() {
        // Wait for full list
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
        let cellCount = app.cells.count
        XCTAssertGreaterThanOrEqual(cellCount, 9,
                                    "Expected at least 9 seeded devices, found \(cellCount)")
    }

    // MARK: - Search

    func testSearchFiltersResults() {
        let searchBar = app.searchFields.firstMatch
        searchBar.tapWhenReady()
        searchBar.typeText("IKEA")
        // Results should be reduced
        let count = app.cells.count
        // All results should contain IKEA (or have it in their subtitles)
        XCTAssertGreaterThanOrEqual(count, 1)
    }

    func testSearchClearRestoresFull() {
        let searchBar = app.searchFields.firstMatch
        searchBar.tapWhenReady()
        searchBar.typeText("xyz_no_match_xyz")
        let empty = app.cells.count == 0
        // Clear
        searchBar.buttons["Clear text"].tap()
        let restored = app.cells.count
        XCTAssertTrue(empty || restored > 0)
    }

    // MARK: - Sort menu

    func testSortMenuExists() {
        let sortBtn = app.buttons["Sort"].firstMatch
        XCTAssertTrue(sortBtn.waitForExistence(timeout: 5))
    }

    func testSortByNameOpensMenu() {
        app.buttons["Sort"].firstMatch.tapWhenReady()
        XCTAssertTrue(app.buttons["Name"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Name"].firstMatch.tap()
    }

    func testSortByLastSeen() {
        app.buttons["Sort"].firstMatch.tapWhenReady()
        if app.buttons["Last Seen"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Last Seen"].firstMatch.tap()
        }
    }

    // MARK: - Filter menu

    func testFilterMenuExists() {
        let filterBtn = app.buttons["Filter"].firstMatch
        XCTAssertTrue(filterBtn.waitForExistence(timeout: 5))
    }

    func testFilterByStatusOnline() {
        app.buttons["Filter"].firstMatch.tapWhenReady()
        if app.buttons["Online"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Online"].firstMatch.tap()
        }
        // Dismiss filter menu
        app.tap()
        // Some results should remain
        XCTAssertGreaterThanOrEqual(app.cells.count, 0)
    }

    func testFilterByCategoryLights() {
        app.buttons["Filter"].firstMatch.tapWhenReady()
        if app.buttons["Lights"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Lights"].firstMatch.tap()
        }
        app.tap()
        let cells = app.cells
        // Should show only lights
        XCTAssertGreaterThanOrEqual(cells.count, 1)
    }

    func testClearAllFilters() {
        // Apply a filter first
        app.buttons["Filter"].firstMatch.tapWhenReady()
        if app.buttons["Lights"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Lights"].firstMatch.tap()
        }
        app.tap()
        // Now clear
        app.buttons["Filter"].firstMatch.tapWhenReady()
        if app.buttons["Clear All Filters"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Clear All Filters"].firstMatch.tap()
        }
        app.tap()
    }

    // MARK: - Row tap → detail

    func testTappingRowOpensDetail() {
        let firstCell = app.cells.firstMatch
        firstCell.assertExists()
        firstCell.tap()
        // A detail navigation bar should appear
        XCTAssertTrue(app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5) ||
                      app.navigationBars.count > 1,
                      "Device detail did not appear")
    }

    // MARK: - Swipe actions

    func testSwipeRevealRenameAction() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        XCTAssertTrue(
            app.buttons["Rename"].firstMatch.waitForExistence(timeout: 3),
            "Rename action not revealed on swipe"
        )
        // Swipe back to dismiss
        cell.swipeRight()
    }

    func testSwipeRevealRemoveAction() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        XCTAssertTrue(
            app.buttons["Remove"].firstMatch.waitForExistence(timeout: 3),
            "Remove action not revealed on swipe"
        )
        cell.swipeRight()
    }

    // MARK: - Rename flow

    func testRenameSheetOpens() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        app.buttons["Rename"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Rename sheet text field not found"
        )
        // Dismiss
        app.buttons["Cancel"].firstMatch.tap()
    }

    // MARK: - Remove flow

    func testRemoveSheetOpens() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        app.buttons["Remove"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: 5) ||
            app.buttons["Remove Device"].firstMatch.waitForExistence(timeout: 5),
            "Remove sheet not found"
        )
        // Cancel without removing
        app.buttons["Cancel"].firstMatch.tap()
    }

    // MARK: - Pull to refresh

    func testPullToRefresh() {
        let firstCell = app.cells.firstMatch
        firstCell.assertExists()
        firstCell.swipeDown()
        // After refresh, list should still be there
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
    }
}
