import XCTest
@testable import Shellbee

@MainActor
final class SettingsWorkspaceRouteTests: XCTestCase {
    private let bridgeID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    func testBridgeRoutesRetainExplicitBridgeIdentity() {
        let routes: [SettingsWorkspaceRoute] = [
            .bridgeOverview(bridgeID), .bridgeConnection(bridgeID), .bridgeGeneral(bridgeID),
            .mqtt(bridgeID), .adapter(bridgeID), .logOutput(bridgeID),
            .homeAssistant(bridgeID), .availability(bridgeID), .ota(bridgeID),
            .health(bridgeID), .network(bridgeID), .deviceFiltering(bridgeID),
            .touchlink(bridgeID), .backup(bridgeID)
        ]

        XCTAssertTrue(routes.allSatisfy { $0.bridgeID == bridgeID })
        XCTAssertEqual(Set(routes.map(\.id)).count, routes.count)
    }

    func testAppRoutesAreNotBridgeScoped() {
        let routes: [SettingsWorkspaceRoute] = [
            .appGeneral, .liveActivities, .notifications, .deviceLibrary, .about, .developer
        ]

        XCTAssertTrue(routes.allSatisfy { $0.bridgeID == nil })
    }

    func testSelectionSurvivesBenignBridgeUpdates() {
        let selection = SettingsWorkspaceRoute.mqtt(bridgeID)

        XCTAssertEqual(
            SettingsWorkspaceRoute.reconciled(selection, availableBridgeIDs: [bridgeID]),
            selection
        )
    }

    func testRemovingSelectedBridgeReturnsToPlaceholder() {
        XCTAssertNil(
            SettingsWorkspaceRoute.reconciled(.health(bridgeID), availableBridgeIDs: [])
        )
    }

    func testAppSelectionSurvivesWhenNoBridgesRemain() {
        XCTAssertEqual(
            SettingsWorkspaceRoute.reconciled(.notifications, availableBridgeIDs: []),
            .notifications
        )
    }
}
