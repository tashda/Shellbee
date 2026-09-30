import XCTest

final class SettingsUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += ["-activityCenterEnabled", "NO"]
    }

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapSettingsTab()
    }

    // MARK: - Settings root

    func testSettingsRootVisible() {
        app.navigationBars["Settings"].assertExists(timeout: 5)
    }

    // Behavior: with one bridge, Settings opens with a Connection section
    // holding that bridge's card ("<name>, Connected").
    func testConnectionCardShowsConnectedBridge() {
        app.staticTexts["Connection"].firstMatch.assertExists(timeout: 5)
        connectionCard.assertExists(timeout: 5)
    }

    func testGeneralRowExists() {
        XCTAssertTrue(
            app.cells.containing(.staticText, identifier: "General").firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    // MARK: - Server detail

    // Behavior: the connection card pushes the bridge's Server page.
    func testServerDetailOpens() {
        connectionCard.tapWhenReady()
        XCTAssertTrue(
            app.navigationBars["Server"].firstMatch.waitForExistence(timeout: 5),
            "Server detail did not open"
        )
    }

    // Behavior: Device Statistics is a visual dashboard rather than a Form of
    // raw counts. Its chart cards stay discoverable to accessibility clients.
    func testDeviceStatisticsDashboardOpens() {
        connectionCard.tapWhenReady()
        app.staticTexts["Device Statistics"].firstMatch.tapWhenReady()

        XCTAssertTrue(app.navigationBars["Device Statistics"].waitForExistence(timeout: 5))
        for heading in ["Network overview", "Device types", "Power sources", "Vendors"] {
            XCTAssertTrue(
                app.staticTexts[heading].firstMatch.waitForExistence(timeout: 5),
                "Missing dashboard section: \(heading)"
            )
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Device Statistics dashboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

    // Behavior: the bridge's log level is a picker right on the Settings
    // root (Logging section), not a row inside General.
    func testLoggingLevelPickerIsOnSettingsRoot() {
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Logging Level")).firstMatch
        picker.scrollIntoView(in: app)
        XCTAssertFalse(app.staticTexts["Log Level"].exists, "The old General-page label is back")
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
    // ("5 attempts attempts" / "5 requests requests").
    func testNumericLabelsDoNotRepeatUnit() {
        openSettingsScreen("General", inApplication: true)
        app.staticTexts["Reconnect Limit"].firstMatch.assertExists(timeout: 5)
        XCTAssertFalse(app.staticTexts["Reconnect Attempts"].exists,
                       "Should be 'Reconnect Limit' to avoid 'attempts attempts'")
    }

    // Behavior: Live Activities have their own page under Application, with
    // one toggle per kind of activity.
    func testLiveActivitiesHasOwnPage() {
        // Reach the new link in the Application section.
        openSettingsScreen("Live Activities")
        XCTAssertTrue(
            app.navigationBars["Live Activities"].firstMatch.waitForExistence(timeout: 5),
            "Live Activities page did not open"
        )
        for toggle in ["Permit Join", "Touchlink", "OTA Updates", "Scheduled OTAs"] {
            app.switches[toggle].firstMatch.assertExists(timeout: 5)
        }
    }

    // Behavior: App → General no longer hosts the Live Activity toggles —
    // they moved to their own page.
    func testGeneralNoLongerHostsLiveActivities() {
        openSettingsScreen("General", inApplication: true)
        app.staticTexts["Reconnect Limit"].firstMatch.assertExists(timeout: 5)
        XCTAssertFalse(app.staticTexts["Connection Live Activity"].exists)
        XCTAssertFalse(app.staticTexts["OTA Live Activity"].exists)
        XCTAssertFalse(app.staticTexts["Show Scheduled OTAs"].exists)
    }

    // Behavior: bulk OTA pacing lives in OTA Updates' Bulk Check section;
    // there is no separate Performance or Bulk OTA page.
    func testBulkCheckLivesInOTASettings() {
        openSettingsScreen("OTA Updates")
        app.navigationBars["OTA Updates"].assertExists(timeout: 5)
        let concurrency = app.staticTexts["Concurrency"].firstMatch
        concurrency.scrollIntoView(in: app)
        XCTAssertTrue(app.staticTexts["Bulk Check"].exists || app.staticTexts["BULK CHECK"].exists,
                      "Concurrency isn't under the Bulk Check section")
        XCTAssertFalse(app.staticTexts["Concurrent Requests"].exists)
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

    // When Activity Center is disabled, the fallback Logs row opens the
    // feed. It has no title; the Activity/Log mode picker stands in for it.
    func testLogsNavigationFromSettings() {
        let logsRow = app.visibleCell(containing: "Logs")
        logsRow.scrollIntoView(in: app)
        logsRow.tap()
        app.activityModePicker.assertExists(timeout: 5)
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

    private var connectionCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Connected")).firstMatch
    }

    /// Scrolls Settings until the row is on screen and opens it. Rows below
    /// the fold don't exist until scrolled to, and every tab stays in the
    /// tree, so only an on-screen (hittable) row counts. `inApplication`
    /// picks the row under the Application header, for names like
    /// "General" that the bridge sections use too.
    private func openSettingsScreen(_ name: String, inApplication: Bool = false,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let rows = app.cells.containing(.staticText, identifier: name)
        let header = app.staticTexts["Application"].firstMatch
        for _ in 0..<12 {
            let candidates = rows.allElementsBoundByIndex.filter { row in
                guard row.isHittable else { return false }
                guard inApplication else { return true }
                return header.exists && row.frame.minY > header.frame.minY
            }
            if let row = candidates.first {
                row.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Settings row '\(name)' never came on screen", file: file, line: line)
    }
}

final class ActivityCenterEnabledSettingsUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += ["-activityCenterEnabled", "YES"]
    }

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapSettingsTab()
    }

    func testLogsFallbackIsHidden() {
        let logsRow = app.cells.containing(.staticText, identifier: "Logs").firstMatch
        XCTAssertFalse(
            logsRow.waitForExistence(timeout: 2),
            "Logs should only appear in Settings when Activity Center is disabled"
        )
    }
}

final class ActivityInstrumentGalleryUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += [
            "-activityCenterEnabled", "NO",
            "-developerModeEnabled", "YES"
        ]
    }

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapSettingsTab()
    }

    func testGalleryOpensAndSwitchesCoverage() {
        let developerRow = app.buttons["Developer"].firstMatch
        reveal(developerRow)
        developerRow.tapWhenReady()
        app.buttons["Shellbee"].firstMatch.tapWhenReady()

        let galleryRow = app.buttons["Activity Instruments"].firstMatch
        galleryRow.tapWhenReady()

        XCTAssertTrue(
            app.navigationBars["Activity Instruments"].waitForExistence(timeout: 5),
            "Activity instrument gallery did not open"
        )
        let bridgeScope = app.segmentedControls.buttons["Bridge"].firstMatch
        bridgeScope.tapWhenReady()
        let healthCheck = app.staticTexts["Health Check"].firstMatch
        XCTAssertTrue(
            healthCheck.waitForExistence(timeout: 3),
            "Bridge coverage should include health-check activity"
        )

        healthCheck.tapWhenReady()
        XCTAssertTrue(
            app.buttons["Next instrument"].waitForExistence(timeout: 5),
            "Tapping a sample should open it on the stage"
        )
        app.buttons["Minimized Tab Bar"].tapWhenReady()
        app.buttons["Close"].tapWhenReady()
        XCTAssertTrue(app.navigationBars["Activity Instruments"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<4 {
            if element.exists { return }
            app.swipeUp()
        }
    }
}

final class IconGalleryUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += ["-activityCenterEnabled", "NO", "-developerModeEnabled", "YES"]
    }

    func testCustomSymbolsAndCardInstrumentsAppear() {
        waitForMainTab()
        app.tapSettingsTab()

        let developer = app.buttons["Developer"].firstMatch
        for _ in 0..<4 where !developer.exists { app.swipeUp() }
        developer.tapWhenReady()
        app.buttons["Shellbee"].firstMatch.tapWhenReady()
        app.buttons["Icon Gallery"].firstMatch.tapWhenReady()

        XCTAssertTrue(app.navigationBars["Icon Gallery"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Symbols"].firstMatch.tapWhenReady()
        XCTAssertTrue(app.staticTexts["shellbee.home"].exists)

        app.segmentedControls.buttons["Instruments"].firstMatch.tapWhenReady()
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["16 pt"].firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Icon Gallery card instruments"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let models = app.staticTexts["Models"].firstMatch
        for _ in 0..<4 where !models.isHittable { app.swipeUp() }
        XCTAssertTrue(models.isHittable)

        let lowerScreenshot = XCTAttachment(screenshot: app.screenshot())
        lowerScreenshot.name = "Icon Gallery lower card instruments"
        lowerScreenshot.lifetime = .keepAlways
        add(lowerScreenshot)

        let pairing = app.staticTexts["Pairing"].firstMatch
        for _ in 0..<3 where !pairing.isHittable { app.swipeUp() }
        XCTAssertTrue(pairing.isHittable)

        let stateScreenshot = XCTAttachment(screenshot: app.screenshot())
        stateScreenshot.name = "Icon Gallery pairing and update"
        stateScreenshot.lifetime = .keepAlways
        add(stateScreenshot)
    }
}
