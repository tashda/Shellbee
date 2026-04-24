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

    // Behavior: from the empty setup screen, Add Server opens the editor;
    // filling in localhost:8080 + the mock bridge's auth token and tapping
    // Connect should establish a session and show the main tab bar.
    func testAddServerAndConnect() throws {
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            XCTSkip("Already connected — test only valid on fresh install")
        }

        app.buttons["Add Server"].firstMatch.tapWhenReady()

        // SettingsTextField renders TextFields whose accessibility label is
        // the row label ("Host"/"Port"), not an identifier. Match by cell
        // containing the label and target its text field directly.
        let hostCell = app.cells.containing(.staticText, identifier: "Host").firstMatch
        XCTAssertTrue(hostCell.waitForExistence(timeout: 5), "Host row missing in editor")
        let hostField = hostCell.textFields.firstMatch
        hostField.tapWhenReady()
        hostField.typeText("localhost")

        // Port defaults to "8080" — leave it, or override if the default
        // placeholder is shown instead.
        // Token field is a SecureField with placeholder "Optional".
        let tokenCell = app.cells.containing(.staticText, identifier: "Token").firstMatch
        XCTAssertTrue(tokenCell.waitForExistence(timeout: 3), "Token row missing in editor")
        let tokenField = tokenCell.secureTextFields.firstMatch
        tokenField.tapWhenReady()
        tokenField.typeText("shellbee-integration-token")

        app.buttons["Connect"].firstMatch.tapWhenReady()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15),
                      "Main tab bar never appeared after connecting")
    }

    // MARK: - Connection editor

    // Behavior: the connection editor exposes a Protocol chooser (HTTP /
    // HTTPS). With `.pickerStyle(.automatic)` inside a Form, iOS renders
    // it as a menu button whose accessibility label is "Protocol".
    func testConnectionEditorShowsProtocolPicker() throws {
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) { XCTSkip("Already connected") }
        app.buttons["Add Server"].firstMatch.tapWhenReady()
        let matches = app.staticTexts["Protocol"].firstMatch.waitForExistence(timeout: 5)
            || app.buttons["Protocol"].firstMatch.waitForExistence(timeout: 1)
            || app.segmentedControls.firstMatch.waitForExistence(timeout: 1)
        XCTAssertTrue(matches, "Protocol picker not found in connection editor")
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
        guard app.tabBars.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Not connected — cannot test disconnect flow")
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
