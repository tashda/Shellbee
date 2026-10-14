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
        let statistics = app.staticTexts["Device Statistics"].firstMatch
        statistics.scrollIntoView(in: app)
        statistics.tap()

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
        app.navigationBars["MQTT"].assertExists(timeout: 5)
        app.staticTexts["Server URL"].firstMatch.assertExists(timeout: 5)
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
        app.navigationBars["Home Assistant"].assertExists(timeout: 5)
        app.switches.firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Availability

    func testAvailabilitySettingsOpens() {
        openSettingsScreen("Availability")
        app.navigationBars["Availability"].assertExists(timeout: 5)
    }

    func testAvailabilityTrackingToggle() {
        openSettingsScreen("Availability")
        let toggle = app.switches["Track Device Availability"].firstMatch
        toggle.assertExists(timeout: 5)
        XCTAssertTrue(toggle.isEnabled, "The availability tracking toggle isn't interactive")
    }

    // MARK: - OTA settings

    func testOTASettingsOpens() {
        openSettingsScreen("OTA Updates")
        app.navigationBars["OTA Updates"].assertExists(timeout: 5)
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
        // the verb-prefixed labels must not exist anywhere on the screen —
        // once the page has rendered, so absence means something.
        app.navigationBars["Home Assistant"].assertExists(timeout: 5)
        app.switches.firstMatch.assertExists(timeout: 5)
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
        // InlineIntField reads as one element, "Concurrency, <value>".
        let concurrency = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Concurrency")).firstMatch
        // Only needs to render, not be tapped, so existence is enough.
        for _ in 0..<8 where !concurrency.exists { app.swipeUp() }
        XCTAssertTrue(concurrency.exists, "No Concurrency setting in OTA Updates")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Bulk Check")).firstMatch.exists,
                      "Concurrency isn't under the Bulk Check section")
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Concurrent Requests")).firstMatch.exists)
    }

    // Behavior: when the section header already disambiguates, the row
    // label drops the redundant qualifier ("Mains-Powered Devices" → "Timeout",
    // not "Offline Timeout").
    func testAvailabilityTimeoutRowsAreUnqualified() {
        openSettingsScreen("Availability")
        // Enable tracking so the timeout sections appear.
        let toggle = app.switches["Track Device Availability"].firstMatch
        toggle.assertExists(timeout: 5)
        if toggle.value as? String == "0" { flip(toggle) }
        // Section headers are drawn in capitals, so match case-insensitively.
        let mains = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Mains-Powered Devices")).firstMatch
        XCTAssertTrue(mains.waitForExistence(timeout: 5), "Enabling tracking didn't show the timeout sections")
        // The row reads "Timeout, <value>"; the legacy qualified label is gone.
        let timeout = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Timeout")).firstMatch
        XCTAssertTrue(timeout.waitForExistence(timeout: 5), "No unqualified Timeout row")
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Offline Timeout")).firstMatch.exists)
    }

    // MARK: - Health

    func testHealthSettingsOpens() {
        openSettingsScreen("Health Checks")
        app.navigationBars["Health Checks"].assertExists(timeout: 5)
    }

    // MARK: - Network

    func testNetworkSettingsOpens() {
        openSettingsScreen("Network & Hardware")
        app.navigationBars["Network & Hardware"].assertExists(timeout: 5)
    }

    // MARK: - App appearance

    func testAppearanceOpens() {
        openSettingsScreen("Appearance")
        app.navigationBars["Appearance"].assertExists(timeout: 5)
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
        app.navigationBars["Touchlink"].assertExists(timeout: 5)
    }

    func testTouchlinkScanButton() {
        openSettingsScreen("Touchlink")
        app.buttons["Scan"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - About

    func testAboutOpens() {
        openSettingsScreen("About")
        app.navigationBars["About"].assertExists(timeout: 5)
    }

    func testAboutShowsAppVersion() {
        openSettingsScreen("About")
        let version = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Version")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5), "About shows no app version")
    }

    // MARK: - Discard alert

    /// A pending change turns Back into Cancel, which asks before throwing
    /// the change away. Keep Editing stays on the page with the change;
    /// Discard Changes leaves it.
    func testDiscardAlertOnNavigationAwayWithChanges() {
        openSettingsScreen("General")
        let toggle = app.switches["Show Elapsed Time"].firstMatch
        toggle.assertExists(timeout: 5)
        let original = toggle.value as? String
        flip(toggle)
        XCTAssertNotEqual(toggle.value as? String, original, "The toggle didn't change")

        let cancel = app.buttons["Cancel"].firstMatch
        cancel.tapWhenReady(timeout: 5)
        let alert = app.alerts["Discard Unsaved Changes?"]
        alert.assertExists(timeout: 5)
        alert.buttons["Keep Editing"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        app.navigationBars["General"].assertExists(timeout: 5)
        XCTAssertNotEqual(toggle.value as? String, original, "Keep Editing lost the pending change")

        cancel.tapWhenReady(timeout: 5)
        alert.assertExists(timeout: 5)
        alert.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.navigationBars["General"].waitForNonExistence(timeout: 5),
                      "Discard Changes didn't leave the page")
    }

    // MARK: - Helpers

    /// Flips a switch in a settings row. The element spans the whole row, so
    /// a plain tap lands on the label; tap where the switch itself is, then
    /// wait for the value to follow.
    private func flip(_ toggle: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let before = toggle.value as? String
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", before ?? ""), object: toggle)
        _ = XCTWaiter().wait(for: [changed], timeout: 5) // lint-allow-vacuous: callers assert the new value
    }

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
        // Absence only means something once the Logging section rendered.
        let logging = app.staticTexts["Logging"].firstMatch
        for _ in 0..<6 where !logging.exists { app.swipeUp() }
        XCTAssertTrue(logging.exists, "Settings never showed its Logging section")
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
        XCTAssertTrue(app.staticTexts["shellbee.home"].waitForExistence(timeout: 5))

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
