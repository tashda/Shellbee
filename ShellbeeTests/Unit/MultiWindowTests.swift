import XCTest
@testable import Shellbee

@MainActor
final class MultiWindowTests: XCTestCase {
    func testEveryWindowDestinationRoundTripsForSceneRestoration() throws {
        let bridgeID = UUID()
        let entryID = UUID()
        let destinations: [ShellbeeWindowDestination] = [
            .home,
            .section(.devices),
            .device(bridgeID: bridgeID, ieeeAddress: "0x00124b0011223344"),
            .group(bridgeID: bridgeID, groupID: 7),
            .activity,
            .log(bridgeID: bridgeID, entryID: entryID),
            .settings(bridgeID: bridgeID),
            .networkMap(bridgeID: bridgeID)
        ]

        let data = try JSONEncoder().encode(destinations)
        let restored = try JSONDecoder().decode([ShellbeeWindowDestination].self, from: data)

        XCTAssertEqual(restored, destinations)
    }

    func testRestoredEntityRoutesRemainBridgeScoped() {
        let firstBridge = UUID()
        let secondBridge = UUID()

        XCTAssertNotEqual(
            ShellbeeWindowDestination.device(bridgeID: firstBridge, ieeeAddress: "same-ieee"),
            ShellbeeWindowDestination.device(bridgeID: secondBridge, ieeeAddress: "same-ieee")
        )
        XCTAssertNotEqual(
            ShellbeeWindowDestination.group(bridgeID: firstBridge, groupID: 1),
            ShellbeeWindowDestination.group(bridgeID: secondBridge, groupID: 1)
        )
    }

    func testSceneNavigationStateIsIndependentPerWindow() {
        let first = SceneNavigationState(selectedTab: .home)
        let second = SceneNavigationState(selectedTab: .logs)
        let bridgeID = UUID()

        first.selectedTab = .devices
        first.pendingDeviceFilter = .offline
        first.selectedBridgeID = bridgeID

        XCTAssertEqual(first.selectedTab, .devices)
        XCTAssertEqual(first.pendingDeviceFilter, .offline)
        XCTAssertEqual(second.selectedTab, .logs)
        XCTAssertNil(second.pendingDeviceFilter)
        XCTAssertEqual(first.selectedBridgeID, bridgeID)
        XCTAssertNil(second.selectedBridgeID)
    }

    func testInfoPlistEnablesMultipleScenes() throws {
        let plist = try XCTUnwrap(Bundle.main.infoDictionary)
        let manifest = try XCTUnwrap(plist["UIApplicationSceneManifest"] as? [String: Any])

        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, true)
    }
}
