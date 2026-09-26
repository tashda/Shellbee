import XCTest
@testable import Shellbee

@MainActor
final class AppKeyboardNavigationTests: XCTestCase {
    func testNumberedShortcutsMatchPublishedSidebarOrder() {
        XCTAssertEqual(
            AppTab.keyboardSections,
            [.home, .devices, .groups, .logs, .networkMap, .settings]
        )
        XCTAssertEqual(AppTab.keyboardSections.map(\.title), [
            "Home", "Devices", "Groups", "Activity", "Network Map", "Settings"
        ])
    }

    func testSearchIsNotANumberedShortcut() {
        XCTAssertFalse(AppTab.keyboardSections.contains(.search))
        XCTAssertEqual(AppTab.search.title, "Search")
    }
}
