import XCTest

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

    func testBatteryHeaderExpandsAndStatisticsCanShowAllBridges() {
        waitForMainTab()
        app.tapHomeTab()

        let header = app.buttons["card-expand-header-batteries"]
        for _ in 0..<8 where !header.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(header.isHittable, "Batteries card did not become visible")
        let headerTop = header.frame.minY
        let collapsed = XCTAttachment(screenshot: app.screenshot())
        collapsed.name = "Batteries collapsed"
        collapsed.lifetime = .keepAlways
        add(collapsed)
        header.tap()
        XCTAssertTrue(app.buttons["card-expand-footer-batteries"].exists)
        let opening = XCTAttachment(screenshot: app.screenshot())
        opening.name = "Batteries opening"
        opening.lifetime = .keepAlways
        add(opening)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertLessThan(abs(header.frame.minY - headerTop), 24,
                          "Expanding the card moved its header instead of growing below it")
        let expanded = XCTAttachment(screenshot: app.screenshot())
        expanded.name = "Batteries expanded"
        expanded.lifetime = .keepAlways
        add(expanded)
        header.tap()

        let statisticsButton = app.buttons["Open Device Statistics"]
        for _ in 0..<8 where !statisticsButton.isHittable {
            app.swipeUp()
        }
        statisticsButton.tapWhenReady()
        let statisticsOpened = app.navigationBars["Device Statistics"].waitForExistence(timeout: 5)
        let allBridgesAvailable = app.buttons["Statistics for All"].waitForExistence(timeout: 5)
        XCTAssertTrue(statisticsOpened)
        XCTAssertTrue(allBridgesAvailable)
    }
}
