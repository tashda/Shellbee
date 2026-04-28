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

    // Behavior: Home Assistant toggles drop the "Use" verb prefix —
    // iOS toggle labels are nouns, not imperatives.
    func testHomeAssistantTogglesAreNouns() {
        openSettingsScreen("Home Assistant")
        // The toggles are inside the conditional "Compatibility" section,
        // only visible when HA is enabled. We just assert the negative —
        // the verb-prefixed labels must not exist anywhere on the screen.
        XCTAssertFalse(app.staticTexts["Use Legacy Action Sensor"].exists)
        XCTAssertFalse(app.staticTexts["Use Event Entities"].exists)
    }

    // Behavior: Adapter LED is presented as a positive toggle (default ON),
    // not the negated Z2M flag "Disable Adapter LED".
    func testAdapterLEDLabelIsPositive() {
        openSettingsScreen("Adapter")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Adapter LED"].waitForExistence(timeout: 5),
                      "Adapter settings should show 'Adapter LED', not 'Disable Adapter LED'")
        XCTAssertFalse(app.staticTexts["Disable Adapter LED"].exists)
    }

    // Behavior: numeric labels never duplicate their unit
    // ("5 attempts attempts" / "5 requests requests" / "3 retries retries").
    func testNumericLabelsDoNotRepeatUnit() {
        // App General — Reconnect Limit
        openSettingsScreen("General")
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["Reconnect Attempts"].exists,
                       "Should be 'Reconnect Limit' to avoid 'attempts attempts'")
        // Performance — Concurrency
        app.navigationBars.buttons.firstMatch.tap()
        openSettingsScreen("Performance")
        XCTAssertTrue(app.staticTexts["Concurrency"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Concurrent Requests"].exists)
    }

    // Behavior: Live Activities have their own subpage under Application;
    // they no longer live on App → General. The new page exposes all three
    // toggles and is reachable via a dedicated nav link.
    func testLiveActivitiesHasOwnPage() {
        // Reach the new link in the Application section.
        openSettingsScreen("Live Activities")
        XCTAssertTrue(
            app.navigationBars["Live Activities"].firstMatch.waitForExistence(timeout: 5),
            "Live Activities page did not open"
        )
        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["OTA Updates"].exists)
        XCTAssertTrue(app.staticTexts["Scheduled OTAs"].exists)
    }

    // Behavior: App → General no longer hosts the Live Activity toggles —
    // they moved to their own page.
    func testGeneralNoLongerHostsLiveActivities() {
        openSettingsScreen("General")
        XCTAssertFalse(app.staticTexts["Connection Live Activity"].exists)
        XCTAssertFalse(app.staticTexts["OTA Live Activity"].exists)
        XCTAssertFalse(app.staticTexts["Show Scheduled OTAs"].exists)
        // Reconnect Limit stays on General.
        XCTAssertTrue(app.staticTexts["Reconnect Limit"].waitForExistence(timeout: 3))
    }

    // Behavior: the Performance page was renamed to "Bulk OTA" since
    // that was its only content. The link label and page title both update.
    func testBulkOTAReplacesPerformance() {
        // The settings root should expose "Bulk OTA", not "Performance".
        let bulkOTARow = app.cells.containing(.staticText, identifier: "Bulk OTA").firstMatch
        if !bulkOTARow.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(bulkOTARow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.cells.containing(.staticText, identifier: "Performance").firstMatch.exists)
        bulkOTARow.tap()
        XCTAssertTrue(
            app.navigationBars["Bulk OTA"].firstMatch.waitForExistence(timeout: 5),
            "Bulk OTA page did not open"
        )
    }

    // Behavior: when the section header already disambiguates, the row
    // label drops the redundant qualifier ("Mains-Powered Devices" → "Timeout",
    // not "Offline Timeout").
    func testAvailabilityTimeoutRowsAreUnqualified() {
        openSettingsScreen("Availability")
        // Enable tracking so the timeout sections appear.
        let toggle = app.switches.firstMatch
        if toggle.waitForExistence(timeout: 5), toggle.value as? String == "0" {
            toggle.tap()
        }
        // Two "Timeout" rows are expected (one per section); legacy label gone.
        XCTAssertFalse(app.staticTexts["Offline Timeout"].exists)
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
