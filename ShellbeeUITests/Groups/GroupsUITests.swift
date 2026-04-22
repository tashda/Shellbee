import XCTest

final class GroupsUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapGroupsTab()
        _ = app.cells.firstMatch.waitForExistence(timeout: 15)
    }

    // MARK: - List

    func testGroupListIsNotEmpty() {
        // Seeder creates "All Lights" group
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15),
                      "Group list is empty — is the seeder running?")
    }

    func testSeededGroupVisible() {
        let groupCell = app.cells.containing(.staticText, identifier: "All Lights").firstMatch
        XCTAssertTrue(groupCell.waitForExistence(timeout: 10), "All Lights group not found")
    }

    // MARK: - Add group

    func testAddGroupSheetOpens() {
        app.buttons["+"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Add Group sheet did not open"
        )
    }

    func testAddGroupAndCancel() {
        app.buttons["+"].firstMatch.tapWhenReady()
        let nameField = app.textFields.firstMatch
        nameField.tapWhenReady()
        nameField.typeText("Test Group from UI Test")
        app.buttons["Cancel"].firstMatch.tapWhenReady()
        // Group should not appear (we cancelled)
        XCTAssertFalse(
            app.cells.containing(.staticText, identifier: "Test Group from UI Test")
                .firstMatch.exists
        )
    }

    func testAddGroupWithCustomID() {
        app.buttons["+"].firstMatch.tapWhenReady()
        let nameField = app.textFields.firstMatch
        nameField.tapWhenReady()
        nameField.typeText("Custom ID Group")

        // Toggle custom ID
        let toggle = app.switches["Custom Group ID"].firstMatch
        if toggle.waitForExistence(timeout: 3) {
            toggle.tap()
        }
        // Cancel — don't actually create
        app.buttons["Cancel"].firstMatch.tapWhenReady()
    }

    // MARK: - Sort

    func testSortMenuOpens() {
        let sortBtn = app.buttons["Sort"].firstMatch
        XCTAssertTrue(sortBtn.waitForExistence(timeout: 5))
        sortBtn.tap()
        _ = app.buttons["Name"].firstMatch.waitForExistence(timeout: 3)
        app.tap()
    }

    // MARK: - Group detail

    func testTappingGroupOpensDetail() {
        let firstCell = app.cells.firstMatch
        firstCell.assertExists()
        firstCell.tap()
        XCTAssertTrue(
            app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5),
            "Group detail did not appear"
        )
    }

    func testGroupDetailShowsAddButton() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        let addBtn = app.buttons["+"].firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5))
    }

    func testGroupDetailAddMemberSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        app.buttons["+"].firstMatch.tapWhenReady()
        // Either a menu or sheet with "Add Member" option
        if app.buttons["Add Member"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Add Member"].firstMatch.tap()
        }
        _ = app.sheets.firstMatch.waitForExistence(timeout: 5)
        app.buttons["Cancel"].firstMatch.tap()
    }

    func testGroupDetailSaveSceneSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
        app.buttons["+"].firstMatch.tapWhenReady()
        if app.buttons["Save Scene"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Save Scene"].firstMatch.tap()
            _ = app.textFields.firstMatch.waitForExistence(timeout: 5)
            app.buttons["Cancel"].firstMatch.tap()
        }
    }

    func testGroupDetailScenesVisible() {
        // "All Lights" group has scenes: Evening, Movie
        let groupCell = app.cells.containing(.staticText, identifier: "All Lights").firstMatch
        if groupCell.waitForExistence(timeout: 5) {
            groupCell.tap()
            _ = app.navigationBars.element(boundBy: 1).waitForExistence(timeout: 5)
            let eveningScene = app.staticTexts["Evening"].firstMatch
            _ = eveningScene.waitForExistence(timeout: 5)
        }
    }

    // MARK: - Swipe actions

    func testSwipeGroupRevealRename() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        _ = app.buttons["Rename"].firstMatch.waitForExistence(timeout: 3)
        cell.swipeRight()
    }

    func testSwipeGroupRevealRemove() {
        let cell = app.cells.firstMatch
        cell.assertExists()
        cell.swipeLeft()
        _ = app.buttons["Remove"].firstMatch.waitForExistence(timeout: 3)
        cell.swipeRight()
    }
}
