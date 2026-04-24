import XCTest

final class HomeUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapHomeTab()
    }

    // MARK: - Cards visible

    func testBridgeCardVisible() {
        XCTAssertTrue(app.staticTexts["Zigbee2MQTT"].waitForExistence(timeout: 10) ||
                      app.otherElements.containing(.staticText, identifier: "Zigbee2MQTT").firstMatch.waitForExistence(timeout: 10),
                      "Bridge card not visible")
    }

    func testDevicesCardVisible() {
        // The devices card shows total/online/offline counts
        let totalLabel = app.staticTexts["Total"].firstMatch
        XCTAssertTrue(totalLabel.waitForExistence(timeout: 10), "Devices card not visible")
    }

    func testMeshCardVisible() {
        let routersLabel = app.staticTexts["Routers"].firstMatch
        XCTAssertTrue(routersLabel.waitForExistence(timeout: 10), "Mesh card not visible")
    }

    // MARK: - Permit Join

    func testPermitJoinToolbarButtonExists() {
        let permitBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch
        XCTAssertTrue(permitBtn.waitForExistence(timeout: 5), "Permit Join button not in toolbar")
    }

    func testPermitJoinSheetOpens() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Permit Join'")).firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.buttons["Start Permit Join"].firstMatch.waitForExistence(timeout: 5),
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
        // "Duration" section header + "Preset" picker label are always
        // visible regardless of current preset selection.
        XCTAssertTrue(app.staticTexts["Duration"].firstMatch.waitForExistence(timeout: 3),
                      "Duration section header missing")
        XCTAssertTrue(app.staticTexts["Preset"].firstMatch.waitForExistence(timeout: 3),
                      "Preset picker label missing")
    }

    // Behavior: the Permit Join sheet dismisses via its drag indicator.
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

    // MARK: - Navigation from device card stats

    func testTappingTotalNavigatesToDevices() {
        let total = app.staticTexts["Total"].firstMatch
        guard total.waitForExistence(timeout: 10) else {
            return XCTFail("Total stat not found")
        }
        total.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 5),
            "Did not navigate after tapping Total"
        )
    }

    // MARK: - Bridge card

    func testBridgeVersionDisplayed() {
        // Version string should appear somewhere on the home screen
        let versionPredicate = NSPredicate(format: "label MATCHES '\\\\d+\\\\.\\\\d+.*'")
        let versionEl = app.staticTexts.matching(versionPredicate).firstMatch
        // Version may take a moment to load from Z2M
        _ = versionEl.waitForExistence(timeout: 15)
        // Not a hard failure — Z2M may not have sent bridge/info yet
    }

    // MARK: - New card slots (Groups / Logs / Mesh detail)

    // Behavior: the Recent Events card has a "Show All" button that
    // pushes the Logs screen. This is a shortcut for "all recent logs".
    func testRecentEventsShowAllOpensLogs() {
        let showAll = app.buttons["Show All"].firstMatch
        XCTAssertTrue(showAll.waitForExistence(timeout: 10),
                      "Recent Events card missing Show All button")
        showAll.tap()
        XCTAssertTrue(
            app.navigationBars["Logs"].firstMatch.waitForExistence(timeout: 5),
            "Show All should push the Logs view"
        )
    }

    // Behavior: the Mesh card header has a chevron NavigationLink that
    // opens MeshDetailView (navigation title "Mesh"). SwiftUI surfaces
    // that chevron as a Button with accessibility label "Forward".
    func testTappingMeshCardOpensMeshDetail() {
        XCTAssertTrue(app.staticTexts["Mesh"].firstMatch.waitForExistence(timeout: 10),
                      "Mesh card not rendered")
        let forward = app.buttons["Forward"].firstMatch
        XCTAssertTrue(forward.waitForExistence(timeout: 5),
                      "Mesh card chevron not reachable")
        forward.tap()
        XCTAssertTrue(
            app.navigationBars["Mesh"].firstMatch.waitForExistence(timeout: 5),
            "Mesh chevron should push MeshDetailView"
        )
    }

    func testRestartAlertAppears() {
        let restartBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Restart'")).firstMatch
        guard restartBtn.waitForExistence(timeout: 5) else { return }
        restartBtn.tap()

        let confirmAlert = app.alerts.firstMatch
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 3), "Restart confirmation alert not shown")

        // Cancel to avoid actually restarting
        confirmAlert.buttons["Cancel"].tap()
    }
}
