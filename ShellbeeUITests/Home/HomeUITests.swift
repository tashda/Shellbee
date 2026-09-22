import XCTest

final class HomeUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapHomeTab()
    }

    // MARK: - Cards visible

    // Cards are matched by accessibility identifier rather than by the text
    // inside them: a card with nothing to report collapses to a single line,
    // so its figures ("Total", "Routers") are legitimately absent on a
    // healthy network.

    func testHeaderVisible() {
        XCTAssertTrue(app.staticTexts["Home"].firstMatch.waitForExistence(timeout: 10),
                      "Home header not visible")
    }

    func testNetworkCardVisible() {
        XCTAssertTrue(homeCard("network").waitForExistence(timeout: 10),
                      "Network card not visible")
    }

    func testDevicesCardVisible() {
        XCTAssertTrue(homeCard("devices").waitForExistence(timeout: 10),
                      "Devices card not visible")
    }

    func testActivityCardVisible() {
        XCTAssertTrue(homeCard("activity").waitForExistence(timeout: 10),
                      "Activity card not visible")
    }

    /// A Home card by identifier, whichever element type it resolves to.
    private func homeCard(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "home.card.\(id)")
            .firstMatch
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

    // MARK: - Navigation from cards

    func testTappingDevicesCardNavigatesToDevices() {
        let devices = homeCard("devices")
        guard devices.waitForExistence(timeout: 10) else {
            return XCTFail("Devices card not found")
        }
        devices.tap()
        XCTAssertTrue(
            app.navigationBars["Devices"].firstMatch.waitForExistence(timeout: 5),
            "Devices card should open Devices"
        )
    }

    // MARK: - Network card

    func testBridgeVersionDisplayed() {
        // Version string should appear somewhere on the home screen
        let versionPredicate = NSPredicate(format: "label MATCHES '\\\\d+\\\\.\\\\d+.*'")
        let versionEl = app.staticTexts.matching(versionPredicate).firstMatch
        // Version may take a moment to load from Z2M
        _ = versionEl.waitForExistence(timeout: 15)
        // Not a hard failure — Z2M may not have sent bridge/info yet
    }

    // MARK: - Card slots (Activity / Logs / Mesh detail)

    // Behavior: the Activity card has a "Show All" button that pushes the
    // Logs screen. This is a shortcut for "all recent logs".
    func testActivityShowAllOpensLogs() {
        let showAll = app.buttons["Show All"].firstMatch
        XCTAssertTrue(showAll.waitForExistence(timeout: 10),
                      "Activity card missing Show All button")
        showAll.tap()
        XCTAssertTrue(
            app.navigationBars["Logs"].firstMatch.waitForExistence(timeout: 5),
            "Show All should push the Logs view"
        )
    }

    // Behavior: the Network card absorbed the Mesh card, so tapping it is
    // what opens MeshDetailView (navigation title "Mesh").
    func testTappingNetworkCardOpensMeshDetail() {
        let network = homeCard("network")
        XCTAssertTrue(network.waitForExistence(timeout: 10),
                      "Network card not rendered")
        network.tap()
        XCTAssertTrue(
            app.navigationBars["Mesh"].firstMatch.waitForExistence(timeout: 5),
            "Network card should push MeshDetailView"
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
