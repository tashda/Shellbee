import XCTest

extension XCUIApplication {
    /// Launches the app pointed at the Docker Z2M stack on localhost:8080.
    func launchForTesting() {
        launchEnvironment["UI_TEST_Z2M_HOST"]  = "localhost"
        launchEnvironment["UI_TEST_Z2M_PORT"]  = "8080"
        launchEnvironment["UI_TEST_Z2M_TOKEN"] = "shellbee-integration-token"
        launchEnvironment["UI_TEST_MODE"]      = "1"
        launch()
    }

    /// Launches against both native mock bridges with stable display names.
    /// The secondary seeder can use duplicate friendly names while retaining
    /// distinct IEEEs, which lets iPad tests catch bridge-scoping regressions.
    func launchForIPadMatrixTesting() {
        launchEnvironment["UI_TEST_Z2M_HOST"] = "localhost"
        launchEnvironment["UI_TEST_Z2M_PORT"] = "8080"
        launchEnvironment["UI_TEST_Z2M_TOKEN"] = "shellbee-integration-token"
        launchEnvironment["UI_TEST_Z2M_NAME"] = "Primary"
        launchEnvironment["UI_TEST_Z2M_SECONDARY_HOST"] = "localhost"
        launchEnvironment["UI_TEST_Z2M_SECONDARY_PORT"] = "8082"
        launchEnvironment["UI_TEST_Z2M_SECONDARY_TOKEN"] = "shellbee-integration-token-2"
        launchEnvironment["UI_TEST_Z2M_SECONDARY_NAME"] = "Secondary"
        launchEnvironment["UI_TEST_MODE"] = "1"
        launch()
    }

    // MARK: - Common navigation

    var tabBar: XCUIElement { tabBars.firstMatch }

    func tapHomeTab()     { tapTab("Home") }
    func tapDevicesTab()  { tapTab("Devices") }
    func tapGroupsTab()   { tapTab("Groups") }
    func tapSettingsTab() { tapTab("Settings") }
    func tapSearchTab()   { tapTab("Search") }

    /// The tab bar minimizes while content scrolls down, leaving only the
    /// selected tab's button, and iOS 26 draws the search tab as its own
    /// button outside the bar. Look in the bar first, expand it if needed,
    /// then fall back to the app-wide button (search).
    func tapTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        // Already on Search: the keyboard hides the tab bar.
        if name == "Search", searchFields.firstMatch.exists { return }
        var tab = tabBar.buttons[name]
        if !(tab.exists && tab.isHittable), tabBar.buttons.firstMatch.exists {
            tabBar.buttons.firstMatch.tap()
        }
        if !tab.waitForExistence(timeout: 3) {
            tab = buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "No '\(name)' tab", file: file, line: line)

        if name == "Search" {
            // Selecting Search raises the keyboard, whose Search key would
            // match this query too, so confirm by the field instead.
            tab.tap()
            if !searchFields.firstMatch.waitForExistence(timeout: 5) { tab.tap() }
            XCTAssertTrue(searchFields.firstMatch.waitForExistence(timeout: 5),
                          "The Search tab didn't open", file: file, line: line)
            return
        }

        // A tap during launch or a tab-bar animation can be dropped, so
        // confirm the tab took and try once more if it didn't.
        for _ in 0..<2 where !tab.isSelected {
            tab.tap()
            _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isSelected == true"), object: tab
            )], timeout: 3)
        }
        XCTAssertTrue(tab.isSelected, "The '\(name)' tab didn't become selected", file: file, line: line)
    }

    /// Opens a device's detail page the way a person finds one in 2.0:
    /// global Search, narrowed to Devices. The Devices list has no search
    /// field of its own, and with 174 mock devices scrolling to one is slow
    /// and depends on screen size.
    func openDevice(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        tapSearchTab()
        let field = searchFields.firstMatch
        field.tapWhenReady(timeout: 10)
        let clear = field.buttons["Clear text"]
        if clear.exists { clear.tap() }
        field.typeText(name)
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Devices,"))
            .firstMatch
            .tapWhenReady(timeout: 10)
        cells.containing(.staticText, identifier: name).firstMatch.tapWhenReady(timeout: 10)
        XCTAssertTrue(deviceIdentity(named: name).waitForExistence(timeout: 10),
                      "\(name)'s detail page did not open from Search", file: file, line: line)
    }

    /// The on-screen row containing `text`. Every tab stays in the
    /// accessibility tree, so a plain `cells.containing` query can match a
    /// row in a hidden tab (reported with an off-screen frame).
    func visibleCell(containing text: String, timeout: TimeInterval = 15) -> XCUIElement {
        let query = cells.containing(.staticText, identifier: text)
        _ = query.firstMatch.waitForExistence(timeout: timeout)
        return query.allElementsBoundByIndex.first(where: \.isHittable) ?? query.firstMatch
    }

    /// The Activity/Log picker at the top of the feed on iPhone, labelled
    /// "Mode, <current mode>".
    var activityModePicker: XCUIElement {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mode,")).firstMatch
    }

    /// The name at the top of a device or group page. The page keeps its
    /// navigation title empty while this is on screen (the name is shown
    /// once), so this, not `navigationBars[name]`, identifies the page.
    func deviceIdentity(named name: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "value == %@", name)).firstMatch
    }
}

extension XCUIElement {
    /// Wait for this element to exist (default 15 s).
    @discardableResult
    func waitToExist(timeout: TimeInterval = 15) -> Bool {
        waitForExistence(timeout: timeout)
    }

    /// Wait for existence, failing with a clear message if not found.
    func assertExists(timeout: TimeInterval = 15, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout),
                      "Element not found: \(self)", file: file, line: line)
    }

    /// Tap after waiting for the element to be hittable.
    func tapWhenReady(timeout: TimeInterval = 15) {
        assertExists(timeout: timeout)
        tap()
    }

    /// Clear a text field and type new text.
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            let del = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            typeText(del)
        }
        typeText(text)
    }

    /// Swipes the screen up until this element is on screen. Lazy lists
    /// don't create rows below the fold, so a plain existence wait misses
    /// them.
    func scrollIntoView(in app: XCUIApplication, maxSwipes: Int = 8,
                        file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(exists && isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(exists && isHittable, "Never scrolled into view: \(self)", file: file, line: line)
    }

    /// A far-travel leading swipe that reliably reveals List trailing swipe
    /// actions even when `allowsFullSwipe: false`. The stock `swipeLeft()`
    /// on iOS 26 is too short to expose multiple swipe buttons.
    func swipeLeftFar() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end   = coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}

/// Returns true when running under UI test automation.
var isUITestingMode: Bool {
    ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1"
}

// MARK: - Base class for all UI tests

class ShellbeeUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        configureAppBeforeLaunch()
        app.launchForTesting()
        assertConnectedToMockBridge()
    }

    /// Override when a suite needs a persisted setting to start in a
    /// particular state. Launch arguments participate in UserDefaults, so
    /// property wrappers see the value before the first settings render.
    func configureAppBeforeLaunch() {}

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// Every suite on this base class needs the mock bridge. If the app is
    /// still on the connection screen the bridge is down, and that has to
    /// fail the run: counting it as an expected failure made a dead bridge
    /// look like a green run.
    /// 45 s covers a job's first, cold launch (the splash waits for the
    /// bundled thumbnails); a warm launch connects in a few seconds.
    private func assertConnectedToMockBridge() {
        guard !app.tabBars.firstMatch.waitForExistence(timeout: 45) else { return }
        let onSetup = app.buttons["Connect"].exists
        XCTFail(onSetup
            ? "The app never connected to the mock bridge on localhost:8080. Start it with 'docker compose up -d'."
            : "The main tab bar never appeared after launch.")
    }

    // MARK: - Convenience

    func waitForMainTab(timeout: TimeInterval = 15) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout),
                      "Main tab bar never appeared — is the Docker stack running?")
    }
}
