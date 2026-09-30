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

        // The sidebar restores the last section across launches.
        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Home")
            .firstMatch
            .tapWhenReady(timeout: 20)
        app.navigationBars["Home"].assertExists(timeout: 20)
        app.typeKey("k", modifierFlags: .command)
        let search = app.searchFields.firstMatch
        search.assertExists(timeout: 10)
        search.typeText("Living Room Light")
        app.cells.containing(.staticText, identifier: "Living Room Light")
            .firstMatch
            .tapWhenReady(timeout: 10)
        app.deviceIdentity(named: "Living Room Light").assertExists(timeout: 15)

        device.orientation = .portrait

        app.deviceIdentity(named: "Living Room Light").assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Changing window geometry terminated Shellbee")
    }
}
