import XCTest

final class MultiWindowUITests: XCTestCase {
    @MainActor
    func testOpeningSecondSceneShowsIndependentDestination() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        let homeMarker = app.navigationBars["Home"]
        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Home")
            .firstMatch
            .tapWhenReady(timeout: 20)
        homeMarker.assertExists(timeout: 20)

        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Activity")
            .firstMatch
            .tapWhenReady(timeout: 15)
        app.navigationBars["Activity"].assertExists(timeout: 15)
        let originalWindowCount = app.windows.count
        app.buttons["open-in-new-window"].firstMatch.tapWhenReady(timeout: 15)

        let secondWindow = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.windows.count > originalWindowCount },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [secondWindow], timeout: 15), .completed)
        app.navigationBars["Activity"].assertExists(timeout: 15)

        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Devices")
            .firstMatch
            .tapWhenReady(timeout: 15)
        app.navigationBars["Devices"].assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Opening a second scene terminated the shared app session")

        // Close the new (key) window so it isn't restored into the next test.
        app.typeKey("w", modifierFlags: .command)
        app.navigationBars["Home"].assertExists(timeout: 15)
    }

    @MainActor
    func testClosingSecondSceneReturnsToOriginalScene() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        let homeMarker = app.navigationBars["Home"]
        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Home")
            .firstMatch
            .tapWhenReady(timeout: 20)
        homeMarker.assertExists(timeout: 20)
        app.typeKey("l", modifierFlags: [.command, .shift])
        app.navigationBars["Activity"].assertExists(timeout: 15)

        app.typeKey("w", modifierFlags: .command)
        homeMarker.assertExists(timeout: 15)
        XCTAssertTrue(app.exists, "Closing the Activity scene terminated Shellbee")
    }

    @MainActor
    func testSecondSceneSurvivesBackgrounding() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchForTesting()
        defer { app.terminate() }

        // Start from Home.
        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: "Home")
            .firstMatch
            .tapWhenReady(timeout: 20)
        app.navigationBars["Home"].assertExists(timeout: 20)
        app.typeKey("l", modifierFlags: [.command, .shift])
        app.navigationBars["Activity"].assertExists(timeout: 15)

        let windowsBefore = app.windows.count

        XCUIDevice.shared.press(.home)
        app.activate()

        // iPadOS decides which window comes forward; what must hold is that
        // the second window survived the trip to the background.
        app.navigationBars["Home"].assertExists(timeout: 15)
        XCTAssertEqual(app.windows.count, windowsBefore, "A window was lost while the app was in the background")
    }
}
