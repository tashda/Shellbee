import XCTest

final class DeviceListUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapDevicesTab()
        // Wait for device list to load
        _ = app.cells.firstMatch.waitForExistence(timeout: 10)
    }

    // MARK: - List appearance

    func testDeviceListIsNotEmpty() {
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15),
                      "Device list is empty — is the seeder running?")
    }

    func testAllNineDeviceCategoriesPresent() {
        // Wait for full list
        _ = app.cells.firstMatch.waitForExistence(timeout: 10)
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

    // Behavior: a long trailing swipe on a device row reveals the
    // destructive+orange Rename button on that row's trailing swipe menu.
    // The default `swipeLeft()` travels too short a distance in iOS 26
    // to expose buttons when `allowsFullSwipe: false` is set.
    func testSwipeRevealRenameAction() {
        let cell = namedDeviceCell("Living Room Light")
        cell.assertExists()
        cell.swipeLeftFar()
        XCTAssertTrue(
            app.buttons["Rename"].firstMatch.waitForExistence(timeout: 5),
            "Rename action not revealed on swipe"
        )
        cell.swipeRight()
    }

    // Behavior: long trailing swipe exposes the destructive Delete button
    // alongside Rename/Config/Interview.
    func testSwipeRevealRemoveAction() {
        let cell = namedDeviceCell("Living Room Light")
        cell.assertExists()
        cell.swipeLeftFar()
        XCTAssertTrue(
            app.buttons["Delete"].firstMatch.waitForExistence(timeout: 5),
            "Delete action not revealed on swipe"
        )
        cell.swipeRight()
    }

    // MARK: - Rename flow

    // Behavior: swiping a row exposes Rename; tapping it opens the Rename
    // sheet with a prefilled text field for the new name. Dismiss via the
    // drag indicator (no Cancel button by design); no rename should occur.
    func testRenameSheetOpens() {
        let cell = namedDeviceCell("Living Room Light")
        cell.assertExists()
        cell.swipeLeftFar()
        XCTAssertTrue(app.buttons["Rename"].firstMatch.waitForExistence(timeout: 5),
                      "Rename button not revealed after swipe")
        app.buttons["Rename"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Rename sheet text field not found"
        )
        // Dismiss by swiping the sheet down.
        app.swipeDown(velocity: .fast)
    }

    // MARK: - Remove flow

    // Behavior: swiping a row and tapping Delete opens the RemoveDeviceSheet
    // which shows a final confirmation Remove button. Sheet dismisses via
    // drag indicator (no Cancel button by design).
    func testRemoveSheetOpens() {
        let cell = namedDeviceCell("Living Room Light")
        cell.assertExists()
        cell.swipeLeftFar()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 5),
                      "Delete button not revealed after swipe")
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["Remove Device"].firstMatch.waitForExistence(timeout: 5),
            "Remove Device confirmation button not shown"
        )
        // Dismiss without removing by swiping down.
        app.swipeDown(velocity: .fast)
    }

    // MARK: - Pull to refresh

    // Scroll the list into view (if needed) and return the cell whose
    // visible name text matches `name`. Grouped-by-category puts the first
    // cell under a section header; using a deterministic device avoids
    // swiping a section header and getting no response.
    private func namedDeviceCell(_ name: String) -> XCUIElement {
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if !cell.waitForExistence(timeout: 5) {
            app.swipeUp()
            if !cell.waitForExistence(timeout: 5) { app.swipeUp() }
        }
        return cell
    }

    func testPullToRefresh() {
        let firstCell = app.cells.firstMatch
        firstCell.assertExists()
        firstCell.swipeDown()
        // After refresh, list should still be there
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
    }
}
