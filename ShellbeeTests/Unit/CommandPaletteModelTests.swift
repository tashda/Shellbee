import XCTest
@testable import Shellbee

@MainActor
final class CommandPaletteModelTests: XCTestCase {
    private let bridgeA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let bridgeB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    func testExactEntityMatchRanksBeforeDeviceActions() {
        let model = makeModel()

        let results = model.results(matching: "Office Sensor")

        XCTAssertEqual(results.first?.title, "Office Sensor")
        XCTAssertEqual(results.first?.subtitle, "Home")
    }

    func testDuplicateNamesKeepBridgeProvenance() {
        let model = makeModel(includeDuplicate: true)

        let devices = model.results(matching: "Office Sensor").filter {
            if case .openDevice = $0.action { return true }
            return false
        }

        XCTAssertEqual(Set(devices.compactMap(\.subtitle)), ["Home", "Lab"])
    }

    func testDisconnectedActionsExplainWhyTheyAreUnavailable() {
        let model = makeModel(secondBridgeConnected: false, includeDuplicate: true)

        let labDevice = model.results(matching: "Office Sensor").first {
            $0.subtitle == "Lab" && $0.title == "Office Sensor"
        }

        XCTAssertEqual(labDevice?.disabledReason, "Bridge is disconnected")
        XCTAssertEqual(labDevice?.isEnabled, false)
    }

    func testNetworkExpensiveCommandsRequireConfirmation() {
        let model = makeModel()

        let ota = model.items.first { if case .checkOTA = $0.action { return true }; return false }
        let map = model.items.first { if case .refreshNetworkMap = $0.action { return true }; return false }

        XCTAssertEqual(ota?.requiresConfirmation, true)
        XCTAssertEqual(map?.requiresConfirmation, true)
    }

    func testNavigationCommandsUsePublishedSectionOrder() {
        let model = makeModel()
        let navigation = model.items.filter { $0.category == .navigation }

        XCTAssertEqual(navigation.map(\.title), AppTab.keyboardSections.map(\.title))
    }

    private func makeModel(
        secondBridgeConnected: Bool = true,
        includeDuplicate: Bool = false
    ) -> CommandPaletteModel {
        let bridges = [
            CommandPaletteBridge(id: bridgeA, name: "Home", isConnected: true, isPermitJoinOpen: false),
            CommandPaletteBridge(id: bridgeB, name: "Lab", isConnected: secondBridgeConnected, isPermitJoinOpen: true)
        ]
        var devices = [
            BridgeBoundDevice(
                bridgeID: bridgeA,
                bridgeName: "Home",
                device: DeviceFixture.sensor(name: "Office Sensor")
            )
        ]
        if includeDuplicate {
            devices.append(BridgeBoundDevice(
                bridgeID: bridgeB,
                bridgeName: "Lab",
                device: DeviceFixture.sensor(ieee: "0x00158d0007654321", name: "Office Sensor")
            ))
        }
        return CommandPaletteModel(bridges: bridges, devices: devices, groups: [])
    }
}
