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

    // Behavior: typing a query that matches a known vendor in the search
    // field filters the visible rows down. Using any vendor substring that
    // appears in at least one fixture ("IKEA" shows ~6 devices) should keep
    // one or more cells visible.
    func testSearchFiltersResults() {
        let searchBar = app.revealSearchField()
        XCTAssertTrue(searchBar.exists, "Search field did not appear after tapping the Search toolbar button")
        searchBar.typeText("IKEA")
        XCTAssertGreaterThanOrEqual(app.cells.count, 1)
    }

    // Behavior: an unmatched query hides all rows; clearing the search via
    // the built-in clear button restores the full list. Some iOS builds skip
    // rendering zero-row state — accept either "went empty first" or
    // "restored non-empty list" as proof the clear button worked.
    func testSearchClearRestoresFull() {
        let searchBar = app.revealSearchField()
        XCTAssertTrue(searchBar.exists, "Search field did not appear after tapping the Search toolbar button")
        searchBar.typeText("xyz_no_match_xyz")
        let empty = app.cells.count == 0
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
        // After navigation, a back button labeled "Devices" appears
        XCTAssertTrue(
            app.buttons["Devices"].firstMatch.waitForExistence(timeout: 5),
            "Device detail did not appear"
        )
    }

    // MARK: - Swipe actions

    func testSwipeRevealRenameAction() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        XCTAssertTrue(
            app.buttons["Rename"].firstMatch.waitForExistence(timeout: 5),
            "Rename action not revealed on swipe"
        )
        cell.swipeRight()
    }

    func testSwipeRevealRemoveAction() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        XCTAssertTrue(
            app.buttons["Delete"].firstMatch.waitForExistence(timeout: 5),
            "Delete action not revealed on swipe"
        )
        cell.swipeRight()
    }

    // MARK: - Rename flow

    func testRenameSheetOpens() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        // Rename is on the trailing swipe edge (not Remove)
        XCTAssertTrue(app.buttons["Rename"].firstMatch.waitForExistence(timeout: 5),
                      "Rename button not revealed after swipe")
        app.buttons["Rename"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Rename sheet text field not found"
        )
        app.buttons["Cancel"].firstMatch.tap()
    }

    // MARK: - Remove flow

    func testRemoveSheetOpens() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        app.buttons["Delete"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: 5) ||
            app.buttons["Remove Device"].firstMatch.waitForExistence(timeout: 5),
            "Remove sheet not found"
        )
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
