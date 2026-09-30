import XCTest

/// The Devices tab against the mock bridge's 174 fixture devices, grouped by
/// type (Lights first) and sorted by name.
final class DeviceListUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        app.tapDevicesTab()
        app.navigationBars["Devices"].assertExists(timeout: 10)
        app.visibleCell(containing: "Bedroom Hue").assertExists()
    }

    // MARK: - List

    func testDevicesAreGroupedByType() {
        app.staticTexts["Lights"].firstMatch.assertExists(timeout: 5)
        // Bedroom Hue is a light; it sorts first among the fixtures' lights.
        XCTAssertTrue(app.visibleCell(containing: "Bedroom Hue").isHittable)
    }

    func testTappingRowOpensDetail() {
        app.visibleCell(containing: "Bedroom Hue").tap()
        app.deviceIdentity(named: "Bedroom Hue").assertExists(timeout: 10)
    }

    func testPullToRefreshKeepsTheList() {
        app.visibleCell(containing: "Bedroom Hue").swipeDown()
        app.visibleCell(containing: "Bedroom Hue").assertExists(timeout: 10)
    }

    // MARK: - Filter

    func testTypeFilterShowsOnlyThatType() {
        applyFilter(submenu: "Type", option: "Covers")
        app.staticTexts["Covers"].firstMatch.assertExists(timeout: 5)
        app.visibleCell(containing: "Living Room Blinds").assertExists(timeout: 5)
        XCTAssertFalse(app.staticTexts["Lights"].exists, "Lights still listed under a Covers filter")
        XCTAssertFalse(app.visibleCell(containing: "Bedroom Hue", timeout: 1).isHittable,
                       "A light is still listed under a Covers filter")
    }

    func testClearFiltersRestoresTheList() {
        applyFilter(submenu: "Type", option: "Covers")
        XCTAssertFalse(app.staticTexts["Lights"].waitForExistence(timeout: 2))

        app.buttons["Filter"].firstMatch.tapWhenReady(timeout: 5)
        app.buttons["Clear Filters"].firstMatch.tapWhenReady(timeout: 5)
        app.staticTexts["Lights"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Sort

    func testSortMenuOffersEveryOrder() {
        app.buttons["Sort"].firstMatch.tapWhenReady(timeout: 5)
        for order in ["Name", "Last Seen", "Link Quality", "Battery"] {
            app.buttons[order].firstMatch.assertExists(timeout: 5)
        }
        app.buttons["Link Quality"].firstMatch.tap()
        app.navigationBars["Devices"].assertExists(timeout: 5)
    }

    // MARK: - Swipe actions

    func testSwipeRevealsRenameAndDelete() {
        app.visibleCell(containing: "Bedroom Hue").swipeLeftFar()
        app.buttons["Rename"].firstMatch.assertExists(timeout: 5)
        app.buttons["Delete"].firstMatch.assertExists(timeout: 5)
    }

    func testRenameOpensPrefilledSheet() {
        app.visibleCell(containing: "Bedroom Hue").swipeLeftFar()
        app.buttons["Rename"].firstMatch.tapWhenReady(timeout: 5)
        app.navigationBars["Rename Device"].assertExists(timeout: 5)
        let field = app.textFields.firstMatch
        field.assertExists(timeout: 5)
        XCTAssertEqual(field.value as? String, "Bedroom Hue", "The rename field isn't prefilled")
    }

    func testDeleteAsksForConfirmation() {
        app.visibleCell(containing: "Bedroom Hue").swipeLeftFar()
        app.buttons["Delete"].firstMatch.tapWhenReady(timeout: 5)
        app.navigationBars["Remove Device"].assertExists(timeout: 5)
        app.buttons["Remove Device"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Helpers

    private func applyFilter(submenu: String, option: String) {
        app.buttons["Filter"].firstMatch.tapWhenReady(timeout: 5)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", submenu))
            .firstMatch
            .tapWhenReady(timeout: 5)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", option))
            .firstMatch
            .tapWhenReady(timeout: 5)
    }
}
