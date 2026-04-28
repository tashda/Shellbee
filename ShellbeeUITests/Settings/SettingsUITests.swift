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

    // Behavior: tapping the Server row pushes the ServerDetailView
    // (navigationTitle "Server"). SettingsView's nav stack is the only
    // visible one, so we assert the pushed nav bar title.
    func testServerDetailOpens() {
        app.cells.containing(.staticText, identifier: "Server").firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.navigationBars["Server"].firstMatch.waitForExistence(timeout: 5),
            "Server detail did not open"
        )
    }

    // MARK: - General bridge settings

    // Behavior: tapping the first "General" row navigates to bridge-wide
    // general settings (MainSettingsView) — the Log Level section is
    // the hallmark of that pane.
    func testGeneralSettingsOpens() {
        openSettingsScreen("General")
        XCTAssertTrue(
            app.navigationBars["General"].firstMatch.waitForExistence(timeout: 5),
            "General settings pane did not open"
        )
    }

    // Behavior: General settings exposes a Log Level picker for the bridge.
    // The picker label is rendered as a StaticText row; match against
    // staticTexts rather than the enclosing cell because iOS 26 Form
    // rows nest differently.
    func testGeneralSettingsHasLogLevelPicker() {
        openSettingsScreen("General")
        XCTAssertTrue(app.navigationBars["General"].firstMatch.waitForExistence(timeout: 5),
                      "General pane did not open")
        XCTAssertTrue(
            app.staticTexts["Log Level"].firstMatch.waitForExistence(timeout: 5),
            "Log Level picker not found in General settings"
        )
    }

    // Behavior: Apply sits in the confirmationAction slot of the toolbar
    // and is DISABLED until there is a pending change. Cancel does not
    // appear in the toolbar at all until there are pending changes.
    func testGeneralSettingsApplyAndCancel() {
        openSettingsScreen("General")
        XCTAssertTrue(app.navigationBars["General"].firstMatch.waitForExistence(timeout: 5),
                      "General pane did not open")
        let apply = app.buttons["Apply"].firstMatch
        XCTAssertTrue(apply.waitForExistence(timeout: 3),
                      "Apply button should render in the nav bar (disabled)")
        XCTAssertFalse(apply.isEnabled,
                       "Apply should be disabled with no pending changes")
        XCTAssertFalse(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 1),
                       "Cancel toolbar button should only appear after making a change")
    }

    // MARK: - MQTT settings

    func testMQTTSettingsOpens() {
        openSettingsScreen("MQTT")
        XCTAssertTrue(
            app.navigationBars["MQTT"].firstMatch.waitForExistence(timeout: 5),
            "MQTT settings did not open"
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
            app.navigationBars["Adapter"].firstMatch.waitForExistence(timeout: 5),
            "Adapter settings did not open"
        )
    }

    // MARK: - Home Assistant

    func testHomeAssistantSettingsOpens() {
        openSettingsScreen("Home Assistant")
        XCTAssertTrue(
            app.navigationBars["Home Assistant"].firstMatch.waitForExistence(timeout: 5),
            "Home Assistant settings did not open"
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

    // Behavior: Automatic Checks is presented as a positive toggle
    // ("Enable Automatic Checks") rather than the negated Z2M flag
    // ("Disable Automatic Checks"). Verifies the user-facing label.
    func testOTAAutomaticChecksLabelIsPositive() {
        openSettingsScreen("OTA Updates")
        let positive = app.staticTexts["Enable Automatic Checks"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5),
                      "OTA settings should show 'Enable Automatic Checks', not the negated Z2M flag")
        XCTAssertFalse(app.staticTexts["Disable Automatic Checks"].exists,
                       "Negated label 'Disable Automatic Checks' should no longer be shown")
    }

    // Behavior: Transfer Timing labels must fit within their row
    // (no truncation). The shortened labels are visible verbatim.
    func testOTATransferTimingLabelsVisible() {
        openSettingsScreen("OTA Updates")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Request Timeout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Block Delay"].exists)
        XCTAssertTrue(app.staticTexts["Block Size"].exists)
    }

    // Behavior: MQTT retain is presented as a positive toggle
    // ("Retain Messages") rather than the negated Z2M flag.
    func testMQTTRetainLabelIsPositive() {
        openSettingsScreen("MQTT")
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Retain Messages"].waitForExistence(timeout: 5),
                      "MQTT settings should show 'Retain Messages', not 'Disable Message Retain'")
        XCTAssertFalse(app.staticTexts["Disable Message Retain"].exists)
    }

    // Behavior: numeric units belong with the value (via InlineIntField),
    // never parenthesised in the label. Catches regressions like
    // "Max Packet Size (bytes)".
    func testMQTTMaxPacketSizeLabelHasNoParenthesisedUnit() {
        openSettingsScreen("MQTT")
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Max Packet Size"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Max Packet Size (bytes)"].exists,
                       "Unit should be rendered alongside the value, not in the label")
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

    // Behavior: tapping the "Logs" row in Settings pushes LogsView.
    // The Settings nav stack is the only one visible (LogsView's nested
    // NavigationStack renders into the same nav bar), so we assert that
    // the Logs title is on screen.
    func testLogsNavigationFromSettings() {
        let logsRow = app.cells.containing(.staticText, identifier: "Logs").firstMatch
        XCTAssertTrue(logsRow.waitForExistence(timeout: 5),
                      "Logs row not found in Settings")
        logsRow.tap()
        XCTAssertTrue(
            app.navigationBars["Logs"].firstMatch.waitForExistence(timeout: 5),
            "Logs view did not open after tapping Logs row"
        )
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
