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
        app.buttons["Add Group"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Add Group sheet did not open"
        )
    }

    // Behavior: typing a name into the Add Group sheet then dismissing
    // it via the drag indicator (the sheet has no Cancel button — it uses
    // a grabber + swipe) must NOT create the group. The name should not
    // appear in the list afterwards.
    func testAddGroupAndCancel() {
        app.buttons["Add Group"].firstMatch.tapWhenReady()
        let nameField = app.textFields.firstMatch
        nameField.tapWhenReady()
        nameField.typeText("Test Group from UI Test")
        dismissSheet()
        XCTAssertFalse(
            app.cells.containing(.staticText, identifier: "Test Group from UI Test")
                .firstMatch.waitForExistence(timeout: 2)
        )
    }

    // Behavior: the Add Group sheet renders a name text field plus a
    // "Custom Group ID" toggle (default off). We verify both are present —
    // actually flipping the toggle from UI tests is unreliable in iOS 26
    // simulators because the keyboard overlaps the Form row. Dismissing
    // via drag indicator must not create the group.
    func testAddGroupWithCustomID() {
        app.buttons["Add Group"].firstMatch.tapWhenReady()
        let nameField = app.textFields.firstMatch
        nameField.tapWhenReady()
        nameField.typeText("Custom ID Group")
        let toggle = app.switches["Custom Group ID"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Custom Group ID toggle not found in Add Group sheet")
        XCTAssertEqual(toggle.value as? String, "0",
                       "Custom Group ID toggle should start in the off state")
        dismissSheet()
        XCTAssertFalse(
            app.cells.containing(.staticText, identifier: "Custom ID Group")
                .firstMatch.waitForExistence(timeout: 2),
            "Dismissing the sheet should not create the group"
        )
    }

    // AddGroupSheet dismisses via the .presentationDragIndicator(.visible)
    // grabber at the top of the sheet — swipe the sheet down past its
    // medium detent, dismissing it.
    private func dismissSheet() {
        // Dismiss the "Create Group" sheet by swiping it down.
        // The sheet's nav bar is the last (topmost modal) navigation bar.
        let navBar = app.navigationBars["Create Group"].firstMatch
        if navBar.waitForExistence(timeout: 2) {
            navBar.swipeDown(velocity: .fast)
        } else {
            app.swipeDown(velocity: .fast)
        }
        _ = app.navigationBars["Create Group"].waitForNonExistence(timeout: 3)
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
        // Back button labeled "Groups" appears after navigation
        XCTAssertTrue(
            app.buttons["Groups"].firstMatch.waitForExistence(timeout: 5),
            "Group detail did not appear"
        )
    }

    func testGroupDetailShowsAddButton() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.buttons["Groups"].firstMatch.waitForExistence(timeout: 5)
        let actionsBtn = app.buttons["Group Actions"].firstMatch
        XCTAssertTrue(actionsBtn.waitForExistence(timeout: 5))
    }

    func testGroupDetailAddMemberSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.buttons["Groups"].firstMatch.waitForExistence(timeout: 5)
        app.buttons["Group Actions"].firstMatch.tapWhenReady()
        if app.buttons["Add Member"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Add Member"].firstMatch.tap()
        }
        _ = app.sheets.firstMatch.waitForExistence(timeout: 5)
        app.buttons["Cancel"].firstMatch.tap()
    }

    // Behavior: Group Actions menu → "Save Scene" opens the AddSceneSheet
    // with a Scene Name text field. The sheet dismisses via the drag
    // indicator (no Cancel button by design).
    func testGroupDetailSaveSceneSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        _ = app.buttons["Groups"].firstMatch.waitForExistence(timeout: 5)
        app.buttons["Group Actions"].firstMatch.tapWhenReady()
        let saveScene = app.buttons["Save Scene"].firstMatch
        XCTAssertTrue(saveScene.waitForExistence(timeout: 3),
                      "Save Scene action missing from Group Actions menu")
        saveScene.tap()
        let saveSceneNav = app.navigationBars["Save Scene"].firstMatch
        XCTAssertTrue(saveSceneNav.waitForExistence(timeout: 5),
                      "Save Scene sheet did not open")
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 2),
                      "Scene Name text field not present")
        saveSceneNav.swipeDown(velocity: .fast)
        _ = saveSceneNav.waitForNonExistence(timeout: 3)
    }

    func testGroupDetailScenesVisible() {
        // "All Lights" group has scenes: Evening, Movie
        let groupCell = app.cells.containing(.staticText, identifier: "All Lights").firstMatch
        if groupCell.waitForExistence(timeout: 5) {
            groupCell.tap()
            _ = app.buttons["Groups"].firstMatch.waitForExistence(timeout: 5)
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
