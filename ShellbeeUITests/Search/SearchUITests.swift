import XCTest

/// Global Search replaced the per-list search fields in 2.0.
final class SearchUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        app.tapSearchTab()
    }

    func testQueryFindsDeviceAndOpensIt() {
        app.openDevice(named: "Kitchen Plug")
    }

    func testDevicesScopeShowsOnlyMatchingDevices() {
        let field = app.searchFields.firstMatch
        field.tapWhenReady(timeout: 10)
        field.typeText("Bedroom")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Devices,"))
            .firstMatch
            .tapWhenReady(timeout: 10)

        let rows = app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", "Bedroom"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No devices matched 'Bedroom'")
        XCTAssertFalse(app.cells.staticTexts["Kitchen Plug"].exists,
                       "A device that doesn't match the query is still listed")
    }

    func testUnmatchedQueryShowsNoResultsAndClearingRestoresSearch() {
        let field = app.searchFields.firstMatch
        field.tapWhenReady(timeout: 10)
        field.typeText("xyz_no_match_xyz")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "No results"))
                        .firstMatch.waitForExistence(timeout: 10),
                      "An unmatched query didn't show the no-results state")

        field.buttons["Clear text"].tapWhenReady(timeout: 5)
        field.typeText("Kitchen")
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Kitchen Plug")
                        .firstMatch.waitForExistence(timeout: 10),
                      "Search didn't recover after clearing an unmatched query")
    }
}
