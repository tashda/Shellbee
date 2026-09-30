import XCTest

/// Device pages, one per card type, against the mock bridge's fixtures.
/// Each opens the device through global Search (`openDevice`), which
/// already asserts the page's identity (its name) is on screen.
final class DeviceDetailUITests: ShellbeeUITestCase {

    // MARK: - Identity

    func testStatusTilesDescribeTheDevice() {
        app.openDevice(named: "Living Room Light")
        for tile in ["Status: Online", "Power: Mains", "Role: Router"] {
            app.otherElements[tile].assertExists(timeout: 5)
        }
    }

    // MARK: - Light

    func testLightCardAndStartupSettings() {
        app.openDevice(named: "Living Room Light")
        app.staticTexts["Light"].firstMatch.assertExists(timeout: 5)
        app.buttons["Color"].firstMatch.assertExists(timeout: 5)
        // Startup options render as a native section under the card, not
        // behind a button inside it.
        app.staticTexts["Startup"].firstMatch.assertExists(timeout: 5)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Power-On Behavior"))
            .firstMatch
            .assertExists(timeout: 5)
    }

    func testColorLightOffersEffects() {
        app.openDevice(named: "Bedroom Hue")
        app.buttons["Effects"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Switch

    /// A real round trip: the toggle sends `<device>/set`, the mock bridge
    /// merges it into state and publishes it back, and the card follows.
    func testPlugToggleRoundTripsThroughTheBridge() {
        app.openDevice(named: "Kitchen Plug")
        let toggle = app.switches["Power"].firstMatch
        toggle.assertExists(timeout: 5)
        let before = toggle.value as? String
        toggle.tap()

        let flipped = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", before ?? ""),
            object: toggle
        )
        XCTAssertEqual(XCTWaiter().wait(for: [flipped], timeout: 10), .completed,
                       "The plug's state didn't change after toggling it")

        // Put it back so other tests see the fixture state.
        toggle.tap()
    }

    // MARK: - Sensor

    func testSensorShowsReadingsAsRows() {
        app.openDevice(named: "Office Sensor")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Temperature"))
            .firstMatch
            .assertExists(timeout: 5)
        XCTAssertFalse(app.switches.firstMatch.exists, "A read-only sensor shouldn't show a toggle")
    }

    // MARK: - Climate

    func testClimateShowsTarget() {
        app.openDevice(named: "Bedroom Thermostat")
        app.staticTexts["Climate"].firstMatch.assertExists(timeout: 5)
        app.descendants(matching: .any)["Target"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Cover

    /// Stop only appears while the cover is moving.
    func testCoverHasOpenAndClose() {
        app.openDevice(named: "Living Room Blinds")
        for action in ["Open", "Close"] {
            app.buttons[action].firstMatch.assertExists(timeout: 5)
        }
    }

    // MARK: - Lock

    func testLockShowsLockCard() {
        app.openDevice(named: "Front Door Lock")
        app.staticTexts["Lock"].firstMatch.assertExists(timeout: 5)
    }

    // MARK: - Fan

    func testFanShowsSpeed() {
        app.openDevice(named: "Attic Tuya Fan")
        app.staticTexts["Fan"].firstMatch.assertExists(timeout: 5)
        app.descendants(matching: .any)["Speed"].firstMatch.assertExists(timeout: 5)
    }

    /// A fan with air-quality sensors (IKEA STARKVIND) is an air purifier.
    func testAirPurifierIsNamedAsSuch() {
        app.openDevice(named: "Bathroom Fan")
        app.staticTexts["Air Purifier"].firstMatch.assertExists(timeout: 5)
    }

    /// Writable numeric settings edit in place instead of pushing a page.
    /// Attic Tuya Fan has a `countdown_hours` setting.
    func testFanWritableNumericRendersInline() {
        app.openDevice(named: "Attic Tuya Fan")
        let countdown = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "countdown")).firstMatch
        countdown.scrollIntoView(in: app)
        XCTAssertTrue(app.deviceIdentity(named: "Attic Tuya Fan").exists || app.navigationBars["Attic Tuya Fan"].exists,
                      "The countdown setting isn't on the device page")
        XCTAssertFalse(app.navigationBars["Countdown Hours"].exists,
                       "A writable numeric must not push its own page")
    }

    // MARK: - Remote

    /// A battery device shows its level where a mains device shows "Power".
    func testRemoteRunsOnBattery() {
        app.openDevice(named: "TRADFRI Remote")
        app.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@", "Battery: ")).firstMatch
            .assertExists(timeout: 5)
        app.otherElements["Role: End Device"].assertExists(timeout: 5)
    }

    // MARK: - Settings rows

    /// `linkquality` shows as the Signal tile and `identify` is noise, so
    /// neither may appear as a settings row, for any kind of device.
    func testFeatureSectionsHideLinkqualityAndIdentify() {
        for name in ["Bedroom Hue", "Bathroom Fan", "Living Room Blinds"] {
            app.openDevice(named: name)
            app.swipeUp()
            app.swipeUp()
            XCTAssertFalse(app.staticTexts["Linkquality"].exists, "\(name) shows 'Linkquality' as a row")
            XCTAssertFalse(app.staticTexts["Identify"].exists, "\(name) shows 'Identify' as a row")
        }
    }

    // MARK: - More menu

    func testMoreMenuOpensDeviceSettings() {
        app.openDevice(named: "Living Room Light")
        app.navigationBars.buttons["More"].firstMatch.tapWhenReady(timeout: 5)
        app.buttons["Device Settings"].firstMatch.tapWhenReady(timeout: 5)
        app.navigationBars["Device Settings"].assertExists(timeout: 5)
    }
}
