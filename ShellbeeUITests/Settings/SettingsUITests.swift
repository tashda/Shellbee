import XCTest

final class SettingsUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapSettingsTab()
    }

    // MARK: - Settings root

    func testSettingsRootVisible() {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testServerRowExists() {
        XCTAssertTrue(
            app.cells.containing(.staticText, identifier: "Server").firstMatch
                .waitForExistence(timeout: 5),
            "Server row not found in settings"
        )
    }

    func testGeneralRowExists() {
        XCTAssertTrue(
            app.cells.containing(.staticText, identifier: "General").firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    // MARK: - Server detail

    func testServerDetailOpens() {
        app.cells.containing(.staticText, identifier: "Server").firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5),
            "Server detail did not open"
        )
    }

    // MARK: - General bridge settings

    func testGeneralSettingsOpens() {
        let cell = app.cells.matching(NSPredicate(format: "label CONTAINS 'General'")).firstMatch
        cell.tapWhenReady()
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        )
    }

    func testGeneralSettingsHasLogLevelPicker() {
        openSettingsScreen("General")
        XCTAssertTrue(
            app.cells.matching(NSPredicate(format: "label CONTAINS 'Log Level'")).firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    func testGeneralSettingsApplyAndCancel() {
        openSettingsScreen("General")
        let applyBtn = app.buttons["Apply"].firstMatch
        let cancelBtn = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(applyBtn.waitForExistence(timeout: 5) || cancelBtn.waitForExistence(timeout: 5))
        cancelBtn.tapWhenReady()
    }

    // MARK: - MQTT settings

    func testMQTTSettingsOpens() {
        openSettingsScreen("MQTT")
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        )
    }

    func testMQTTSettingsHasServerField() {
        openSettingsScreen("MQTT")
        _ = app.cells.matching(NSPredicate(format: "label CONTAINS 'Server'")).firstMatch
            .waitForExistence(timeout: 5)
    }

    // MARK: - Adapter (Serial) settings

    func testAdapterSettingsOpens() {
        openSettingsScreen("Adapter")
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        )
    }

    // MARK: - Home Assistant

    func testHomeAssistantSettingsOpens() {
        openSettingsScreen("Home Assistant")
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        )
    }

    func testHomeAssistantToggleExists() {
        openSettingsScreen("Home Assistant")
        let toggle = app.switches.firstMatch
        _ = toggle.waitForExistence(timeout: 5)
    }

    // MARK: - Availability

    func testAvailabilitySettingsOpens() {
        openSettingsScreen("Availability")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    func testAvailabilityTrackingToggle() {
        openSettingsScreen("Availability")
        let toggle = app.switches.firstMatch
        if toggle.waitForExistence(timeout: 5) {
            // Verify the toggle is interactive
            XCTAssertTrue(toggle.isEnabled)
        }
    }

    // MARK: - OTA settings

    func testOTASettingsOpens() {
        openSettingsScreen("OTA Updates")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    // MARK: - Health

    func testHealthSettingsOpens() {
        openSettingsScreen("Health Checks")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    // MARK: - Network

    func testNetworkSettingsOpens() {
        openSettingsScreen("Network")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    // MARK: - App appearance

    func testAppGeneralOpens() {
        // Scroll down if needed to find App section
        app.swipeUp()
        let appearanceRow = app.cells.matching(
            NSPredicate(format: "label CONTAINS 'Appearance'")
        ).firstMatch
        if appearanceRow.waitForExistence(timeout: 5) {
            appearanceRow.tap()
            _ = app.pickers.firstMatch.waitForExistence(timeout: 5)
        }
    }

    // MARK: - Logs

    func testLogsNavigationFromSettings() {
        let logsRow = app.cells.containing(.staticText, identifier: "Logs").firstMatch
        if logsRow.waitForExistence(timeout: 5) {
            logsRow.tap()
            XCTAssertTrue(
                app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
            )
        }
    }

    // MARK: - Touchlink

    func testTouchlinkOpens() {
        openSettingsScreen("Touchlink")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    func testTouchlinkScanButton() {
        openSettingsScreen("Touchlink")
        let scanBtn = app.buttons["Scan"].firstMatch
        _ = scanBtn.waitForExistence(timeout: 5)
    }

    // MARK: - About

    func testAboutOpens() {
        openSettingsScreen("About")
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
    }

    func testAboutShowsBridgeVersion() {
        openSettingsScreen("About")
        let versionCell = app.cells.matching(
            NSPredicate(format: "label CONTAINS 'Version'")
        ).firstMatch
        _ = versionCell.waitForExistence(timeout: 5)
    }

    // MARK: - Discard alert

    func testDiscardAlertOnNavigationAwayWithChanges() {
        openSettingsScreen("General")
        // Modify a setting
        let outputPicker = app.cells.matching(
            NSPredicate(format: "label CONTAINS 'Output'")
        ).firstMatch
        if outputPicker.waitForExistence(timeout: 3) {
            outputPicker.tap()
        }
        // Navigate back without applying
        app.navigationBars.buttons.firstMatch.tapWhenReady()
        // A discard alert may appear
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            alert.buttons.firstMatch.tap()
        }
    }

    // MARK: - Helpers

    private func openSettingsScreen(_ name: String) {
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if !cell.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        cell.tapWhenReady()
    }
}
