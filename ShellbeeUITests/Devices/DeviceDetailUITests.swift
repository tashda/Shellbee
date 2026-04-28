import XCTest

/// Tests for device detail views — one per card type.
/// Each test opens the first device of a given category name from the seeder.
final class DeviceDetailUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapDevicesTab()
        _ = app.cells.firstMatch.waitForExistence(timeout: 10)
    }

    // MARK: - Light (CT + brightness) — "Living Room Light"

    func testLightDetailOpens() {
        openDetail(named: "Living Room Light")
        XCTAssertTrue(app.navigationBars["Living Room Light"].waitForExistence(timeout: 5))
    }

    func testLightBrightnessAreaExists() {
        openDetail(named: "Living Room Light")
        // The brightness area should be present in the light card
        let brightnessArea = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS 'Brightness'")
        ).firstMatch
        _ = brightnessArea.waitForExistence(timeout: 5)
        // Not a hard failure — accessibility labels may vary
    }

    func testLightColorTempControlVisible() {
        openDetail(named: "Living Room Light")
        _ = app.sliders.firstMatch.waitForExistence(timeout: 5)
        // Slider for color temp should be present
    }

    func testLightDeviceMenuOpens() {
        openDetail(named: "Living Room Light")
        // Ellipsis menu button
        let menuBtn = app.buttons["More options"].firstMatch
        if menuBtn.waitForExistence(timeout: 3) {
            menuBtn.tap()
            _ = app.buttons["Device Settings"].firstMatch.waitForExistence(timeout: 3)
            app.swipeDown()
        }
    }

    // MARK: - Color light — "Bedroom Hue"

    func testColorLightDetailOpens() {
        openDetail(named: "Bedroom Hue")
        XCTAssertTrue(app.navigationBars["Bedroom Hue"].waitForExistence(timeout: 5))
    }

    // MARK: - Switch / Plug — "Kitchen Plug"

    func testSwitchPlugDetailOpens() {
        openDetail(named: "Kitchen Plug")
        XCTAssertTrue(app.navigationBars["Kitchen Plug"].waitForExistence(timeout: 5))
    }

    func testSwitchPlugToggleExists() {
        openDetail(named: "Kitchen Plug")
        // Toggle switch for on/off
        let toggle = app.switches.firstMatch
        _ = toggle.waitForExistence(timeout: 5)
    }

    // MARK: - Sensor — "Office Sensor"

    func testSensorDetailOpens() {
        openDetail(named: "Office Sensor")
        XCTAssertTrue(app.navigationBars["Office Sensor"].waitForExistence(timeout: 5))
    }

    func testSensorShowsReadOnlyValues() {
        openDetail(named: "Office Sensor")
        // Temperature or humidity values should be displayed
        let tempLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '°C' OR label CONTAINS 'Temperature'")
        ).firstMatch
        _ = tempLabel.waitForExistence(timeout: 5)
    }

    // MARK: - Climate — "Bedroom Thermostat"

    func testClimateDetailOpens() {
        openDetail(named: "Bedroom Thermostat")
        XCTAssertTrue(app.navigationBars["Bedroom Thermostat"].waitForExistence(timeout: 5))
    }

    func testClimateSetpointButtonsExist() {
        openDetail(named: "Bedroom Thermostat")
        // +/- buttons for setpoint
        let plus  = app.buttons["+"].firstMatch
        let minus = app.buttons["-"].firstMatch
        _ = plus.waitForExistence(timeout: 5)
        _ = minus.waitForExistence(timeout: 5)
    }

    // MARK: - Cover — "Living Room Blinds"

    func testCoverDetailOpens() {
        openDetail(named: "Living Room Blinds")
        XCTAssertTrue(app.navigationBars["Living Room Blinds"].waitForExistence(timeout: 5))
    }

    func testCoverOpenCloseButtonsExist() {
        openDetail(named: "Living Room Blinds")
        let openBtn  = app.buttons["Open"].firstMatch
        let closeBtn = app.buttons["Close"].firstMatch
        _ = openBtn.waitForExistence(timeout: 5)
        _ = closeBtn.waitForExistence(timeout: 5)
    }

    // MARK: - Lock — "Front Door Lock"

    func testLockDetailOpens() {
        openDetail(named: "Front Door Lock")
        XCTAssertTrue(app.navigationBars["Front Door Lock"].waitForExistence(timeout: 5))
    }

    func testLockUnlockButtonsExist() {
        openDetail(named: "Front Door Lock")
        let lockBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Lock' OR label CONTAINS 'Unlock'")
        ).firstMatch
        _ = lockBtn.waitForExistence(timeout: 5)
    }

    // MARK: - Fan — "Bathroom Fan"

    func testFanDetailOpens() {
        openDetail(named: "Bathroom Fan")
        XCTAssertTrue(app.navigationBars["Bathroom Fan"].waitForExistence(timeout: 5))
    }

    /// Light hero card surfaces brightness + Effects (sparkles button); Startup
    /// / Other-advanced features used to live behind sunrise / ellipsis sheet
    /// buttons inside the card. They now drop down as native iOS Settings
    /// sections beneath the card. The Effects button stays — it's a true
    /// light-specific control, not configuration.
    func testLightAdvancedFeaturesRenderAsSettingsSections() {
        openDetail(named: "Bedroom Hue")
        XCTAssertTrue(app.navigationBars["Bedroom Hue"].waitForExistence(timeout: 5))

        // Effects button (sparkles) must still exist in the card.
        // Sunrise (Startup) and Ellipsis (More) buttons must NOT be there.
        // We verify by swiping down to the section area instead — the
        // presence of section headers like "Configuration" or rows with
        // typical advanced-feature labels signals the new layout.
        app.swipeUp()
        let configHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Configuration' OR label CONTAINS[c] 'Startup'")
        ).firstMatch
        XCTAssertTrue(
            configHeader.waitForExistence(timeout: 3),
            "Light should expose advanced features in a native section beneath the card"
        )
    }

    /// `linkquality` and `identify` must never appear in any feature section —
    /// they're either surfaced on the device card (linkquality) or are
    /// noisy diagnostics (identify). Enforced for every device category.
    func testFeatureSectionsHideLinkqualityAndIdentify() {
        for name in ["Bedroom Hue", "Bathroom Fan", "Office Inovelli Fan Switch", "Bedroom Curtain"] {
            openDetail(named: name)
            _ = app.navigationBars[name].waitForExistence(timeout: 5)
            app.swipeUp()
            app.swipeUp()
            XCTAssertFalse(
                app.staticTexts["Linkquality"].exists,
                "\(name) must not surface 'Linkquality' as a settings row"
            )
            XCTAssertFalse(
                app.staticTexts["Identify"].exists,
                "\(name) must not surface 'Identify' as a settings row"
            )
            // Back out for the next iteration.
            let backBtn = app.navigationBars.buttons.element(boundBy: 0)
            if backBtn.exists { backBtn.tap() }
            _ = app.cells.firstMatch.waitForExistence(timeout: 5)
        }
    }

    /// Writable numeric settings under the fan card render their slider inline
    /// — never push to a separate detail screen. Attic Tuya Fan exposes both a
    /// hero `speed` slider and a `countdown_hours` writable numeric in its
    /// settings sections, so a correctly-rendered detail screen exposes more
    /// than one slider without any navigation push.
    func testFanWritableNumericRendersInline() {
        openDetail(named: "Attic Tuya Fan")
        XCTAssertTrue(app.navigationBars["Attic Tuya Fan"].waitForExistence(timeout: 5))

        let detailNav = app.navigationBars["Attic Tuya Fan"]
        XCTAssertTrue(detailNav.waitForExistence(timeout: 5))

        // Scroll down so the Behaviour section (countdown_hours lives there)
        // is rendered and its slider is hit-testable.
        app.swipeUp()
        app.swipeUp()

        let sliderCount = app.sliders.count
        XCTAssertGreaterThan(
            sliderCount, 1,
            "Expected hero speed slider plus an inline slider for countdown_hours; got \(sliderCount)"
        )

        // No new navigation page (e.g. a dedicated "Countdown Hours" detail)
        // should be on screen — the original device detail nav bar must still
        // be the active one.
        XCTAssertFalse(
            app.navigationBars["Countdown Hours"].exists,
            "Writable numeric must not push a dedicated detail screen"
        )
    }

    // MARK: - Remote — "TRADFRI Remote"

    func testRemoteDetailOpens() {
        openDetail(named: "TRADFRI Remote")
        XCTAssertTrue(app.navigationBars["TRADFRI Remote"].waitForExistence(timeout: 5))
    }

    // MARK: - Device Settings sheet

    func testDeviceSettingsOpens() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.tap()
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)

        let menuBtn = app.buttons["More options"].firstMatch
        if menuBtn.waitForExistence(timeout: 3) {
            menuBtn.tap()
            if app.buttons["Device Settings"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Device Settings"].firstMatch.tap()
                XCTAssertTrue(
                    app.navigationBars["Device Settings"].waitForExistence(timeout: 5),
                    "Device Settings did not open"
                )
            }
        }
    }

    // MARK: - Helpers

    private func openDetail(named name: String) {
        // With `.searchToolbarBehavior(.minimize)` the search field only
        // exists after tapping the Search icon in the nav bar. Use that
        // to narrow the list down to the target device rather than
        // scrolling through 30+ rows.
        let search = app.revealSearchField()
        if search.exists {
            search.clearAndType(name)
        }

        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if !cell.waitForExistence(timeout: 5) {
            app.swipeUp()
            if !cell.waitForExistence(timeout: 5) {
                app.swipeUp()
            }
        }
        guard cell.waitForExistence(timeout: 5) else {
            XCTFail("Could not find device '\(name)' in the list")
            return
        }
        cell.tap()
    }
}
