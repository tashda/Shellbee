import XCTest

/// Home's cards with two bridges connected and the opt-in Vendors card on.
final class HomeDashboardUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += [
            "-homeCard.batteries.enabled", "YES",
            "-homeCard.vendors.enabled", "YES",
        ]
        app.launchEnvironment["UI_TEST_Z2M_SECONDARY_HOST"] = "localhost"
        app.launchEnvironment["UI_TEST_Z2M_SECONDARY_PORT"] = "8082"
        app.launchEnvironment["UI_TEST_Z2M_SECONDARY_TOKEN"] = "shellbee-integration-token-2"
        app.launchEnvironment["UI_TEST_Z2M_SECONDARY_NAME"] = "Secondary"
    }

    override func setUp() {
        super.setUp()
        app.tapHomeTab()
        app.navigationBars["Home"].assertExists(timeout: 10)
    }

    func testBatteriesCardOpensBatteriesPage() {
        let open = app.buttons["Open Batteries"].firstMatch
        open.scrollIntoView(in: app)
        open.tap()
        app.navigationBars["Batteries"].assertExists(timeout: 5)
    }

    func testDeviceStatisticsCanShowAllBridges() {
        let open = app.buttons["Open Device Statistics"].firstMatch
        open.scrollIntoView(in: app)
        open.tap()
        app.navigationBars["Device Statistics"].assertExists(timeout: 5)
        app.buttons["Statistics for All"].firstMatch.assertExists(timeout: 5)
    }

    /// Expanding a card grows it downwards; its header must stay put.
    func testExpandingVendorsKeepsItsHeaderInPlace() {
        let header = app.buttons["card-expand-header-vendors"]
        header.scrollIntoView(in: app, maxSwipes: 10)
        let top = header.frame.minY
        header.tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertLessThan(abs(header.frame.minY - top), 24,
                          "Expanding Vendors moved its header instead of growing below it")
        header.tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertLessThan(abs(header.frame.minY - top), 24, "Collapsing Vendors moved its header")
    }
}
