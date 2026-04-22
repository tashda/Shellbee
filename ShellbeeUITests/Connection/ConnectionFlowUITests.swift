import XCTest

final class ConnectionFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch WITHOUT pre-configured server so we exercise the setup flow
        app.launchEnvironment["UI_TEST_MODE"] = "1"
        app.launchEnvironment["UI_TEST_CLEAR_SAVED_SERVER"] = "1"
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Setup screen appears on fresh launch

    func testConnectionSetupAppearsOnFreshLaunch() {
        // Should land on the connection overview / setup screen
        let addButton = app.buttons["Add Server"].firstMatch
            .waitForExistence(timeout: 5)
        // If we get the main tabs instead (server was saved), skip
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            XCTSkip("A saved server was found — reset app state to test this flow")
        }
        XCTAssertTrue(addButton, "Expected connection setup screen on fresh launch")
    }

    // MARK: - Add server and connect

    func testAddServerAndConnect() throws {
        // Skip if already connected
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            XCTSkip("Already connected — test only valid on fresh install")
        }

        app.buttons["Add Server"].firstMatch.tapWhenReady()

        // Fill in host
        let hostField = app.textFields.matching(identifier: "Host").firstMatch
        hostField.tapWhenReady()
        hostField.clearAndType("localhost")

        // Port should default to 8080 — verify or set it
        let portField = app.textFields.matching(identifier: "Port").firstMatch
        if portField.exists {
            portField.clearAndType("8080")
        }

        // Tap Connect
        app.buttons["Connect"].firstMatch.tapWhenReady()

        // Main tab bar should appear (within 30s while Z2M connects)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30),
                      "Main tab bar never appeared after connecting")
    }

    // MARK: - Connection editor

    func testConnectionEditorShowsProtocolPicker() throws {
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) { XCTSkip("Already connected") }
        app.buttons["Add Server"].firstMatch.tapWhenReady()
        // Protocol picker should be present
        XCTAssertTrue(
            app.segmentedControls.firstMatch.waitForExistence(timeout: 5) ||
            app.pickers["Protocol"].waitForExistence(timeout: 5),
            "Protocol picker not found in editor"
        )
    }

    // MARK: - Saved connections

    func testSavedConnectionAppearsInList() throws {
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) { XCTSkip("Already connected") }
        // If the history list has any entries, the first one should be tappable
        let firstHistory = app.cells.firstMatch
        if firstHistory.waitForExistence(timeout: 3) {
            XCTAssertTrue(firstHistory.isHittable)
        }
    }

    // MARK: - Disconnect

    func testDisconnectReturnsToSetupScreen() throws {
        // This test requires being connected first
        guard app.tabBars.firstMatch.waitForExistence(timeout: 30) else {
            XCTSkip("Not connected — cannot test disconnect flow")
        }

        app.tapSettingsTab()

        // Scroll to bottom to find Disconnect button
        let disconnect = app.buttons["Disconnect"].firstMatch
        if !disconnect.waitForExistence(timeout: 5) {
            // Try scrolling down
            app.swipeUp()
        }
        disconnect.tapWhenReady()

        // Confirm in alert if one appears
        let confirmBtn = app.buttons["Disconnect"].firstMatch
        if confirmBtn.waitForExistence(timeout: 3) {
            confirmBtn.tap()
        }

        // Should return to connection setup
        XCTAssertTrue(
            app.buttons["Add Server"].firstMatch.waitForExistence(timeout: 10),
            "Expected to return to connection setup screen after disconnect"
        )
    }
}
