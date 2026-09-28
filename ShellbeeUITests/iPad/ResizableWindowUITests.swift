import XCTest

final class ResizableWindowUITests: XCTestCase {
    @MainActor
    func testDeviceSelectionSurvivesGeometryBreakpointChange() {
        continueAfterFailure = false
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        device.orientation = .landscapeLeft

        let app = XCUIApplication()
        app.launchForTesting()
        defer {
            app.terminate()
            device.orientation = originalOrientation
        }

        app.staticTexts["Total"].firstMatch.assertExists(timeout: 20)
        app.typeKey("k", modifierFlags: .command)
        let search = app.searchFields.firstMatch
        search.assertExists(timeout: 10)
        search.typeText("Living Room Light")
        app.cells.containing(.staticText, identifier: "Living Room Light")
            .firstMatch
            .tapWhenReady(timeout: 10)
        app.navigationBars["Living Room Light"].assertExists(timeout: 15)

        device.orientation = .portrait

        app.navigationBars["Living Room Light"].assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Changing window geometry terminated Shellbee")
    }
}
