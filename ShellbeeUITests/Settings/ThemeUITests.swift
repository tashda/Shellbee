import XCTest

final class ThemeUITests: ShellbeeUITestCase {
    override func configureAppBeforeLaunch() {
        app.launchArguments += [
            "-appearanceMode", "dark",
            "-activityCenterEnabled", "NO",
        ]
    }

    func testDarkPreviewAndThemeSelection() {
        waitForMainTab()
        app.tapSettingsTab()
        app.cells.containing(.staticText, identifier: "Appearance").firstMatch.tapWhenReady()

        XCTAssertTrue(app.staticTexts["Color Theme"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Color Theme"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Color Theme"].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Dark theme previews"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let harbor = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Harbor")
        ).firstMatch
        XCTAssertTrue(harbor.waitForExistence(timeout: 5))
        harbor.tap()
        app.navigationBars["Color Theme"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Harbor"].firstMatch.waitForExistence(timeout: 5))
    }
}
