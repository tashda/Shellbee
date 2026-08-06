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

    func testSearchRequestTargetsSearchableSection() {
        var request = AppSearchFocusRequest()

        request.request(for: .devices)

        XCTAssertEqual(request.sequence, 1)
        XCTAssertEqual(request.section, .devices)
    }

    func testRepeatedSearchRequestChangesSequence() {
        var request = AppSearchFocusRequest()

        request.request(for: .logs)
        request.request(for: .logs)

        XCTAssertEqual(request.sequence, 2)
        XCTAssertEqual(request.section, .logs)
    }

    func testSearchRequestIgnoresSectionWithoutSearch() {
        var request = AppSearchFocusRequest()

        request.request(for: .settings)

        XCTAssertEqual(request, AppSearchFocusRequest())
    }
}
