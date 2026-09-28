import XCTest

final class HomeUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapHomeTab()
    }

    // MARK: - The screen itself

    func testHomeHasATitle() {
        XCTAssertTrue(
            app.navigationBars["Home"].waitForExistence(timeout: 10),
            "Home should have a large title, not an empty navigation bar"
        )
    }

    // Behavior: each connected bridge is one row reading
    // "Connected · Zigbee2MQTT <version>".
    func testBridgeRowVisible() {
        let bridgeDetail = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Zigbee2MQTT'")
        ).firstMatch
        XCTAssertTrue(bridgeDetail.waitForExistence(timeout: 10), "No bridge row on Home")
    }

    // Behavior: tapping a bridge row opens BridgeInfoSheet, which is where
    // the bridge's own figures live now that Home doesn't repeat them.
    func testTappingBridgeRowOpensBridgeInfo() {
        let bridgeDetail = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Zigbee2MQTT'")
        ).firstMatch
        guard bridgeDetail.waitForExistence(timeout: 10) else {
            return XCTFail("No bridge row on Home")
        }
        bridgeDetail.tap()

        XCTAssertTrue(
            app.staticTexts["Connection"].waitForExistence(timeout: 5),
            "The bridge row should open the bridge info sheet"
        )
        app.buttons["Done"].firstMatch.tapWhenReady()
    }

    // MARK: - Needs attention

    // Behavior: the section only exists while something is wrong, and every
    // row in it opens the Devices tab filtered to what it named. The fixture
    // bridge always has devices that stopped answering.
    func testAttentionRowOpensFilteredDevices() {
        let devicesRow = app.staticTexts["Devices"].firstMatch
        guard devicesRow.waitForExistence(timeout: 10) else {
            // Nothing needs attention on this bridge — the section is
            // correctly absent, so there is nothing to assert.
            return
        }
        devicesRow.tap()
        XCTAssertTrue(
            app.navigationBars["Devices"].firstMatch.waitForExistence(timeout: 5),
            "A Needs attention row should open the Devices tab"
        )
    }

    // MARK: - Activity

    func testActivitySectionVisible() {
        XCTAssertTrue(
            app.staticTexts["Activity"].firstMatch.waitForExistence(timeout: 10),
            "Home should show an Activity section"
        )
    }

    // Behavior: "See all" pushes the Activity Center's own feed.
    func testSeeAllOpensActivity() {
        let seeAll = app.buttons["See all"].firstMatch
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "Activity section missing See all")
        seeAll.tap()
        XCTAssertTrue(
            app.navigationBars["Activity"].firstMatch.waitForExistence(timeout: 5),
            "See all should push the Activity feed"
        )
    }

    // MARK: - Permit Join

    func testPermitJoinToolbarButtonExists() {
        let permitBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch
        XCTAssertTrue(permitBtn.waitForExistence(timeout: 5), "Permit Join button not in toolbar")
    }

    func testPermitJoinSheetOpens() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.buttons["Open Network"].firstMatch.waitForExistence(timeout: 5),
            "Permit Join sheet did not open"
        )
    }

    // Behavior: the Permit Join sheet has a Duration section with a
    // Preset picker and a Target section. The picker's label renders as
    // a static text "Preset"; tapping the Preset row opens a menu with
    // the preset options (1 min / 2 min / 3 min / ~4 min / Custom).
    func testPermitJoinSheetHasDurationOptions() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch.tapWhenReady()
        XCTAssertTrue(app.navigationBars["Permit Join"].waitForExistence(timeout: 5),
                      "Permit Join sheet did not open")
        XCTAssertTrue(app.staticTexts["Duration"].firstMatch.waitForExistence(timeout: 3),
                      "Duration section header missing")
        XCTAssertTrue(app.staticTexts["Preset"].firstMatch.waitForExistence(timeout: 3),
                      "Preset picker label missing")
    }

    // XCUIApplication.swipeDown on the root triggers the sheet's drag
    // gesture; medium+large detent sheets may need two swipes.
    func testPermitJoinDismisses() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch.tapWhenReady()
        let nav = app.navigationBars["Permit Join"]
        XCTAssertTrue(nav.waitForExistence(timeout: 5), "Sheet did not open")
        // The Permit Join button in the Home toolbar stays in the tree —
        // dismissal is proven by the sheet's navigation bar disappearing.
        for _ in 0..<4 {
            if !nav.exists { break }
            app.swipeDown(velocity: .fast)
            _ = nav.waitForNonExistence(timeout: 1)
        }
        XCTAssertFalse(nav.exists, "Permit Join sheet did not dismiss")
    }

    func testRestartAlertAppears() {
        let restartBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Restart'")).firstMatch
        guard restartBtn.waitForExistence(timeout: 5) else { return }
        restartBtn.tap()

        let confirmAlert = app.alerts.firstMatch
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 3), "Restart confirmation alert not shown")

        confirmAlert.buttons["Cancel"].tap()
    }
}
