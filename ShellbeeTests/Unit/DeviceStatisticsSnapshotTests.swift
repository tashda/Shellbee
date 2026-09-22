import XCTest
@testable import Shellbee

@MainActor
final class DeviceStatisticsSnapshotTests: XCTestCase {
    func testDashboardCountsExcludeCoordinatorAndSeparateAvailability() {
        var router = DeviceFixture.light()
        router.powerSource = "Mains (single phase)"
        router.manufacturer = "Acme"

        var sensor = DeviceFixture.sensor()
        sensor.powerSource = "Battery"
        sensor.manufacturer = "Acme"

        var remote = DeviceFixture.remote(name: "Untracked Remote")
        remote.availability = .bool(false)
        remote.powerSource = "Battery"
        remote.manufacturer = "Other"

        let snapshot = DeviceStatisticsSnapshot(
            devices: [DeviceFixture.coordinator(), router, sensor, remote],
            availability: [router.friendlyName: true, sensor.friendlyName: false],
            states: [
                router.friendlyName: ["linkquality": .int(180)],
                sensor.friendlyName: ["linkquality": .int(100)],
            ]
        )

        XCTAssertEqual(snapshot.totalDevices, 3)
        XCTAssertEqual(snapshot.onlineDevices, 1)
        XCTAssertEqual(snapshot.offlineDevices, 1)
        XCTAssertEqual(snapshot.untrackedDevices, 1)
        XCTAssertEqual(snapshot.batteryDevices, 2)
        XCTAssertEqual(snapshot.devicesReportingLinkQuality, 2)
        XCTAssertEqual(snapshot.averageLinkQuality, 140)
        XCTAssertEqual(snapshot.deviceTypes.map(\.title), ["End devices", "Routers"])
    }

    func testRankingsSortByCountThenNameAndPreserveEveryCategory() {
        let alphaOne = DeviceFixture.light(name: "Alpha One", vendor: "Alpha", model: "Model A")

        let alphaTwo = DeviceFixture.light(
            ieee: "0xB",
            name: "Alpha Two",
            vendor: "Alpha",
            model: "Model B"
        )

        let beta = DeviceFixture.light(
            ieee: "0xC",
            name: "Beta One",
            vendor: "Beta",
            model: "Model C"
        )

        let snapshot = DeviceStatisticsSnapshot(
            devices: [alphaOne, alphaTwo, beta],
            availability: [:],
            states: [:]
        )

        XCTAssertEqual(snapshot.vendors.map(\.title), ["Alpha", "Beta"])
        XCTAssertEqual(snapshot.vendors.map(\.count), [2, 1])
        XCTAssertEqual(snapshot.models.map(\.title), ["Model A", "Model B", "Model C"])
        XCTAssertEqual(snapshot.distinctVendors, 2)
        XCTAssertEqual(snapshot.distinctModels, 3)
    }
}
