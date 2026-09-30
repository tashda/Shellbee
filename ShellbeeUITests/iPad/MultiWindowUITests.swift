import XCTest

/// One launch walks the whole multi-window story. Split across launches,
/// the tests fought each other: iPadOS restores every window a previous
/// launch left open, and opening a window for a destination that's already
/// open brings that window forward instead of making a new one.
final class MultiWindowUITests: XCTestCase {
    @MainActor
    func testSecondWindowIsIndependentClosesAndSurvivesBackgrounding() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        let sidebar = app.collectionViews["Sidebar"]
        func openSection(_ name: String) {
            sidebar.cells.containing(.staticText, identifier: name).firstMatch.tapWhenReady(timeout: 20)
        }

        openSection("Home")
        app.navigationBars["Home"].assertExists(timeout: 20)
        openSection("Activity")
        app.navigationBars["Activity"].assertExists(timeout: 15)

        // Open Activity in a second window.
        let windowsBefore = app.windows.count
        app.buttons["open-in-new-window"].firstMatch.tapWhenReady(timeout: 15)
        let opened = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.windows.count > windowsBefore },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 15), .completed, "No second window opened")
        app.navigationBars["Activity"].assertExists(timeout: 15)

        // The new window navigates on its own.
        openSection("Devices")
        app.navigationBars["Devices"].assertExists(timeout: 15)

        // Closing it returns to the original window, still on Activity.
        app.typeKey("w", modifierFlags: .command)
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.windows.count == windowsBefore },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 15), .completed, "The second window didn't close")
        app.navigationBars["Activity"].assertExists(timeout: 15)

        // The window survives a trip to the background.
        XCUIDevice.shared.press(.home)
        app.activate()
        app.navigationBars["Activity"].assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Shellbee didn't come back from the background")
    }
}
