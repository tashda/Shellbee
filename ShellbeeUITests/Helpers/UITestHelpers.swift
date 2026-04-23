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

    // MARK: - Common navigation

    var tabBar: XCUIElement { tabBars.firstMatch }

    func tapHomeTab()     { tabBar.buttons["Home"].tap() }
    func tapDevicesTab()  { tabBar.buttons["Devices"].tap() }
    func tapGroupsTab()   { tabBar.buttons["Groups"].tap() }
    func tapSettingsTab() { tabBar.buttons["Settings"].tap() }

    /// Reveal the minimized search bar on lists that use
    /// `.searchToolbarBehavior(.minimize)`. The search field only exists in
    /// the view hierarchy after the user taps the magnifying-glass icon in
    /// the navigation bar — scrolling does not reveal it.
    ///
    /// Returns the search field if it became available within the timeout.
    @discardableResult
    func revealSearchField(timeout: TimeInterval = 5) -> XCUIElement {
        let field = searchFields.firstMatch
        if field.waitForExistence(timeout: 1) { return field }

        // The .minimize search icon is exposed as a Button labeled "Search".
        let searchButton = navigationBars.buttons["Search"].firstMatch
        if searchButton.waitForExistence(timeout: timeout) {
            searchButton.tap()
        }
        _ = field.waitForExistence(timeout: timeout)
        return field
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
        app.launchForTesting()
        skipIfZ2MUnavailable()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    /// Skip if the Z2M Docker stack isn't up (detected by whether the
    /// connection setup screen is still showing after a reasonable wait).
    private func skipIfZ2MUnavailable() {
        // If the app connected successfully the main tab bar should appear.
        // If not, we get stuck on the connection setup screen.
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 30) {
            // Try to detect whether we're on a connection setup screen
            let isSetup = app.buttons["Connect"].waitForExistence(timeout: 3)
            if isSetup {
                XCTExpectFailure("Docker Z2M stack not running — run 'docker compose up -d'")
            }
        }
    }

    // MARK: - Convenience

    func waitForMainTab(timeout: TimeInterval = 30) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout),
                      "Main tab bar never appeared — is the Docker stack running?")
    }

    func navigateToDeviceDetail(named name: String) {
        app.tapDevicesTab()
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        cell.assertExists()
        cell.tap()
    }
}
