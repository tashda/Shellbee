import XCTest
@testable import Shellbee

@MainActor
final class LogsWorkspaceStateTests: XCTestCase {
    func testModeSwitchPreservesIndependentFilterState() {
        let workspace = LogsWorkspaceState()
        workspace.activity.selectedCategory = .availability
        workspace.activity.selectedLevel = .warning
        workspace.mode = .log
        workspace.bridge.selectedLevel = .debug
        workspace.mode = .activity

        XCTAssertEqual(workspace.activity.selectedCategory, .availability)
        XCTAssertEqual(workspace.activity.selectedLevel, .warning)
        XCTAssertEqual(workspace.bridge.selectedLevel, .debug)
    }

    func testSearchAndCategoryFiltersCompose() {
        let store = AppStore()
        store.logEntries = [
            entry(message: "Office Sensor offline", category: .availability, device: "Office Sensor"),
            entry(message: "Office Sensor temperature changed", category: .stateChange, device: "Office Sensor"),
            entry(message: "Kitchen Sensor offline", category: .availability, device: "Kitchen Sensor")
        ]
        let model = LogsViewModel()
        model.searchText = "Office"
        model.selectedCategory = .availability

        let results = model.filteredEntries(store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.message, "Office Sensor offline")
    }

    func testActivityAndRawBridgeFiltersRemainIndependent() {
        let workspace = LogsWorkspaceState()
        let activityBridge = UUID()
        let rawBridge = UUID()

        workspace.activity.bridgeFilter = activityBridge
        workspace.bridge.bridgeFilter = rawBridge

        XCTAssertEqual(workspace.activity.bridgeFilter, activityBridge)
        XCTAssertEqual(workspace.bridge.bridgeFilter, rawBridge)
    }

    private func entry(
        message: String,
        category: LogCategory,
        device: String
    ) -> LogEntry {
        LogEntry(
            id: UUID(), timestamp: .now, level: .warning,
            category: category, namespace: "z2m", message: message,
            deviceName: device
        )
    }
}
