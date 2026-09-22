import XCTest

final class IPadShellMatrixUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForIPadMatrixTesting()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    @MainActor
    func testPrimaryWorkspacesAndDeviceLibraryAreReachable() {
        waitForBothBridges()
        app.staticTexts["Total"].firstMatch.assertExists(timeout: 20)

        openSidebarSection("Devices", expectedTitle: "Devices")
        app.cells.containing(.staticText, identifier: "Living Room Light")
            .firstMatch
            .assertExists(timeout: 15)

        openSidebarSection("Groups", expectedTitle: "Groups")
        app.cells.containing(.staticText, identifier: "All Lights")
            .firstMatch
            .assertExists(timeout: 15)

        openSidebarSection("Activity", expectedTitle: "Logs")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "Activity did not load any rows")

        openSidebarSection("Network Map", expectedTitle: "Network Map")
        app.staticTexts["Network Map"].firstMatch.assertExists(timeout: 15)

        openSidebarSection("Settings", expectedTitle: "Settings")
        app.cells.containing(.staticText, identifier: "Device Library")
            .firstMatch
            .tapWhenReady(timeout: 10)
        app.navigationBars["Device Library"].assertExists(timeout: 15)
    }

    @MainActor
    func testDuplicateNamesRouteDetailsAndScopeLogsToSelectedBridge() {
        waitForBothBridges()

        openSidebarSection("Devices", expectedTitle: "Devices")
        app.buttons["Secondary"].tapWhenReady(timeout: 15)
        visibleCell(containing: "Living Room Light")
            .tapWhenReady(timeout: 15)
        assertSecondaryDetail(title: "Living Room Light")

        openSidebarSection("Groups", expectedTitle: "Groups")
        app.buttons["Filter"].firstMatch.tapWhenReady(timeout: 10)
        app.buttons["Secondary"].tapWhenReady(timeout: 10)
        visibleCell(containing: "All Lights")
            .tapWhenReady(timeout: 15)
        assertSecondaryDetail(title: "All Lights")

        openSidebarSection("Activity", expectedTitle: "Logs")
        app.buttons["Secondary"].tapWhenReady(timeout: 15)
        app.cells.containing(.any, identifier: "activity-log-Secondary")
            .firstMatch
            .assertExists(timeout: 20)
        XCTAssertFalse(
            app.cells.containing(.any, identifier: "activity-log-Primary")
                .firstMatch
                .waitForExistence(timeout: 2),
            "The Secondary activity filter leaked a Primary bridge log"
        )
    }

    @MainActor
    func testSelectionSurvivesNarrowPortraitFallbackAndReturn() {
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        device.orientation = .landscapeLeft
        waitForBothBridges()
        openSidebarSection("Devices", expectedTitle: "Devices")
        app.buttons["Secondary"].tapWhenReady(timeout: 15)
        visibleCell(containing: "Living Room Light")
            .tapWhenReady(timeout: 15)
        assertSecondaryDetail(title: "Living Room Light")

        device.orientation = .portrait
        assertSecondaryDetail(title: "Living Room Light")
        device.orientation = .landscapeLeft
        assertSecondaryDetail(title: "Living Room Light")
    }

    @MainActor
    private func waitForBothBridges() {
        app.staticTexts["Secondary"].firstMatch.assertExists(timeout: 25)
    }

    @MainActor
    private func openSidebarSection(_ section: String, expectedTitle: String) {
        app.collectionViews["Sidebar"].cells.containing(.staticText, identifier: section)
            .firstMatch
            .tapWhenReady(timeout: 15)
        app.navigationBars[expectedTitle].assertExists(timeout: 15)
    }

    @MainActor
    private func assertSecondaryDetail(title: String) {
        app.navigationBars[title].assertExists(timeout: 15)
        app.descendants(matching: .any)["Bridge: Secondary"].assertExists(timeout: 15)
    }

    @MainActor
    private func visibleCell(containing text: String) -> XCUIElement {
        let query = app.cells.containing(.staticText, identifier: text)
        _ = query.firstMatch.waitForExistence(timeout: 15)
        return query.allElementsBoundByIndex.first(where: \.isHittable) ?? query.firstMatch
    }
}
