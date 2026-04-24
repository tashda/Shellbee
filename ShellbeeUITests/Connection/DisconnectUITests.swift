import XCTest

final class DisconnectUITests: ShellbeeUITestCase {

    // Behavior: from an auto-connected session, tapping Settings →
    // Disconnect → confirming the alert drops the session and returns
    // the app to the setup screen where the "Add Server" button is
    // visible again. Validates the full connected-to-setup transition.
    func testDisconnectReturnsToSetupScreen() {
        waitForMainTab()
        app.tapSettingsTab()
        XCTAssertTrue(
            app.navigationBars["Settings"].firstMatch.waitForExistence(timeout: 5),
            "Settings view did not appear after tapping tab"
        )

        // Disconnect sits in a destructive section at the bottom of the
        // Form. In iOS 26, SwiftUI Forms back onto a UICollectionView —
        // scroll that view (not the whole app, to avoid the tab bar
        // swallowing the gesture) until Disconnect becomes hittable.
        let disconnect = app.buttons["Disconnect"].firstMatch
        let scrollTarget = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.scrollViews.firstMatch
        for _ in 0..<12 {
            if disconnect.exists && disconnect.isHittable { break }
            scrollTarget.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(disconnect.exists && disconnect.isHittable,
                      "Disconnect button not reachable after scrolling Settings")
        disconnect.tap()

        // Confirm in the alert.
        let confirmAlert = app.alerts.firstMatch
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 3),
                      "Disconnect confirmation alert did not appear")
        confirmAlert.buttons["Disconnect"].firstMatch.tap()

        XCTAssertTrue(
            app.buttons["Add Server"].firstMatch.waitForExistence(timeout: 10),
            "Expected to return to connection setup screen after disconnect"
        )
    }
}
