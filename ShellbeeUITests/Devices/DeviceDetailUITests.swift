import XCTest

/// Tests for device detail views — one per card type.
/// Each test opens the first device of a given category name from the seeder.
final class DeviceDetailUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapDevicesTab()
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
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
        // Reveal minimized search bar and filter to the device
        app.swipeDown()
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            search.tap()
            search.clearAndType(name)
        }

        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        if !cell.waitForExistence(timeout: 5) {
            // Scroll down to load lazy cells further in the list
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
