import XCTest

final class DisconnectUITests: ShellbeeUITestCase {

    // Behavior: Settings › More › Disconnect, confirmed, drops the session
    // and returns to the connection screen, where Add Server is offered.
    func testDisconnectReturnsToSetupScreen() {
        app.tapSettingsTab()
        app.navigationBars["Settings"].assertExists(timeout: 5)

        app.navigationBars["Settings"].buttons["More"].tapWhenReady(timeout: 5)
        app.buttons["Disconnect"].firstMatch.tapWhenReady(timeout: 5)

        let alert = app.alerts["Disconnect from Server?"]
        alert.assertExists(timeout: 5)
        alert.buttons["Disconnect"].tap()

        app.navigationBars["Connect"].assertExists(timeout: 10)
        app.buttons["Add Server"].firstMatch.assertExists(timeout: 5)
        XCTAssertFalse(app.tabBars.firstMatch.exists, "The main tabs are still showing after disconnecting")
    }
}
