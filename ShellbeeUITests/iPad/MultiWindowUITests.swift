import XCTest

final class MultiWindowUITests: XCTestCase {
    @MainActor
    func testOpeningSecondSceneShowsIndependentDestination() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        let homeMarker = app.staticTexts["Total"].firstMatch
        homeMarker.assertExists(timeout: 20)
        app.typeKey("l", modifierFlags: [.command, .shift])
        app.navigationBars["Logs"].assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Opening a second scene terminated the shared app session")
    }

    @MainActor
    func testClosingSecondSceneReturnsToOriginalScene() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        let homeMarker = app.staticTexts["Total"].firstMatch
        homeMarker.assertExists(timeout: 20)
        app.typeKey("l", modifierFlags: [.command, .shift])
        app.navigationBars["Logs"].assertExists(timeout: 15)

        app.typeKey("w", modifierFlags: .command)
        homeMarker.assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Closing the Activity scene terminated Shellbee")
    }

    @MainActor
    func testSecondSceneRestoresAfterBackgrounding() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        app.staticTexts["Total"].firstMatch.assertExists(timeout: 20)
        app.typeKey("l", modifierFlags: [.command, .shift])
        app.navigationBars["Logs"].assertExists(timeout: 15)

        XCUIDevice.shared.press(.home)
        app.activate()

        app.navigationBars["Logs"].assertExists(timeout: 15)
    }
}
