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
        app.navigationBars["Home"].assertExists(timeout: 20)

        openSidebarSection("Devices", expectedTitle: "Devices")
        app.cells.containing(.staticText, identifier: "Living Room Light")
            .firstMatch
            .assertExists(timeout: 15)

        openSidebarSection("Groups", expectedTitle: "Groups")
        app.cells.containing(.staticText, identifier: "All Lights")
            .firstMatch
            .assertExists(timeout: 15)

        openSidebarSection("Activity", expectedTitle: "Activity")
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
        selectSecondaryBridgeFilter(openingSubmenu: app.buttons["Bridge"])
        visibleCell(containing: "All Lights")
            .tapWhenReady(timeout: 15)
        assertSecondaryDetail(title: "All Lights")

        openSidebarSection("Activity", expectedTitle: "Activity")
        selectSecondaryBridgeInSidebar()
        activityEvents(fromBridge: "Secondary")
            .firstMatch
            .assertExists(timeout: 20)
        XCTAssertFalse(
            activityEvents(fromBridge: "Primary")
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

    /// The sidebar already shows a "Secondary" row, so wait for the submenu
    /// to add its own before tapping the newest one. Reading the elements
    /// straight after the tap raced the menu's animation.
    @MainActor
    private func selectSecondaryBridgeFilter(openingSubmenu submenu: XCUIElement) {
        let options = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Secondary"))
        let countBefore = options.count
        submenu.tapWhenReady(timeout: 10)
        let appeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count > %d", countBefore),
                                                 object: options)
        guard XCTWaiter().wait(for: [appeared], timeout: 10) == .completed,
              let option = options.allElementsBoundByIndex.last else {
            return XCTFail("The Secondary bridge filter option was not found")
        }
        option.tapWhenReady(timeout: 10)
    }

    @MainActor
    private func selectSecondaryBridgeInSidebar() {
        app.collectionViews["Sidebar"].buttons["Secondary"]
            .tapWhenReady(timeout: 10)
    }

    /// Activity cards read as one element whose label ends with the bridge
    /// monogram's "Bridge: <name>", so this also guards that VoiceOver says
    /// which bridge an event came from.
    @MainActor
    private func activityEvents(fromBridge name: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bridge: \(name)"))
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
        let identity = app.buttons.matching(NSPredicate(format: "value == %@", title)).firstMatch
        identity.assertExists(timeout: 15)
        app.descendants(matching: .any)["Bridge: Secondary"].assertExists(timeout: 15)
    }

    @MainActor
    private func visibleCell(containing text: String) -> XCUIElement {
        let query = app.cells.containing(.staticText, identifier: text)
        _ = query.firstMatch.waitForExistence(timeout: 15)
        return query.allElementsBoundByIndex.first(where: \.isHittable) ?? query.firstMatch
    }
}
