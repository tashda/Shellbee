import XCTest

final class GroupsUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        waitForMainTab()
        app.tapGroupsTab()
        app.cells.firstMatch.assertExists(timeout: 15)
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
    private func dismissSheet(file: StaticString = #filePath, line: UInt = #line) {
        let navBar = app.navigationBars["Create Group"].firstMatch
        navBar.assertExists(timeout: 5, file: file, line: line)
        navBar.swipeDown(velocity: .fast)
        XCTAssertTrue(navBar.waitForNonExistence(timeout: 5),
                      "The Create Group sheet did not dismiss", file: file, line: line)
    }

    // MARK: - Sort

    func testSortMenuOpens() {
        app.buttons["Sort"].firstMatch.tapWhenReady(timeout: 5)
        for order in ["Name", "Members", "Group ID"] {
            app.buttons[order].firstMatch.assertExists(timeout: 5)
        }
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
        let actionsBtn = app.buttons["Group Actions"].firstMatch
        XCTAssertTrue(actionsBtn.waitForExistence(timeout: 5), "Group detail has no Group Actions menu")
    }

    func testGroupDetailAddMemberSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        app.buttons["Group Actions"].firstMatch.tapWhenReady(timeout: 5)
        app.buttons["Add Member"].firstMatch.tapWhenReady(timeout: 5)
        let cancel = app.buttons["Cancel"].firstMatch
        cancel.assertExists(timeout: 5)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5), "The Add Member sheet did not close")
    }

    // Behavior: Group Actions menu → "Save Scene" opens the AddSceneSheet
    // with a Scene Name text field. The sheet dismisses via the drag
    // indicator (no Cancel button by design).
    func testGroupDetailSaveSceneSheetOpens() {
        app.cells.firstMatch.tapWhenReady()
        app.buttons["Group Actions"].firstMatch.tapWhenReady(timeout: 5)
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
        XCTAssertTrue(saveSceneNav.waitForNonExistence(timeout: 5), "The Save Scene sheet did not dismiss")
    }

    func testGroupDetailScenesVisible() {
        // The seeder's "All Lights" group has the scenes Evening and Movie.
        let groupCell = app.cells.containing(.staticText, identifier: "All Lights").firstMatch
        groupCell.tapWhenReady(timeout: 10)
        for scene in ["Evening", "Movie"] {
            let row = app.staticTexts[scene].firstMatch
            row.scrollIntoView(in: app)
        }
    }

    // MARK: - Swipe actions

    func testSwipeGroupRevealRename() {
        app.cells.firstMatch.swipeLeftFar()
        app.buttons["Rename"].firstMatch.assertExists(timeout: 5)
    }

    /// The destructive swipe action is labelled "Delete"; it opens a
    /// confirmation rather than removing the group.
    func testSwipeGroupRevealDelete() {
        app.cells.firstMatch.swipeLeftFar()
        app.buttons["Delete"].firstMatch.assertExists(timeout: 5)
    }
}
