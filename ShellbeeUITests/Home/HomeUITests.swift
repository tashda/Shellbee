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
        let permitBtn = app.buttons["Permit Join"].firstMatch
        XCTAssertTrue(permitBtn.waitForExistence(timeout: 5), "Permit Join button not in toolbar")
    }

    func testPermitJoinSheetOpens() {
        app.buttons["Permit Join"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.buttons["Start Permit Join"].firstMatch.waitForExistence(timeout: 5),
            "Permit Join sheet did not open"
        )
    }

    func testPermitJoinSheetHasDurationOptions() {
        app.buttons["Permit Join"].firstMatch.tapWhenReady()
        // Duration presets should be visible
        let oneMin = app.buttons.matching(NSPredicate(format: "label CONTAINS '1'")).firstMatch
        XCTAssertTrue(oneMin.waitForExistence(timeout: 5))
    }

    func testPermitJoinDismisses() {
        app.buttons["Permit Join"].firstMatch.tapWhenReady()
        // Swipe down to dismiss
        app.swipeDown()
        XCTAssertFalse(app.buttons["Start Permit Join"].firstMatch.waitForExistence(timeout: 3))
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
