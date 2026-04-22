import XCTest
@testable import Shellbee

final class DeviceListViewModelTests: XCTestCase, @unchecked Sendable {

    var store: AppStore!
    var vm: DeviceListViewModel!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            store = AppStore()
            vm = DeviceListViewModel()

            store.apply(.devices(DeviceFixture.allCategoryDevices))

            for device in store.devices {
                store.apply(.deviceAvailability(friendlyName: device.friendlyName, available: true))
                store.apply(.deviceState(friendlyName: device.friendlyName,
                                         state: ["linkquality": .int(100), "battery": .int(80)]))
            }
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            store = nil
            vm = nil
        }
        super.tearDown()
    }

    // MARK: - Baseline

    @MainActor
    func testAllDevicesReturnedByDefault() {
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, DeviceFixture.allCategoryDevices.count)
    }

    // MARK: - Status filter

    @MainActor
    func testFilterOnline() {
        store.apply(.deviceAvailability(friendlyName: "Office Sensor", available: false))
        vm.statusFilter = .online
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { store.isAvailable($0.friendlyName) })
        XCTAssertFalse(result.contains { $0.friendlyName == "Office Sensor" })
    }

    @MainActor
    func testFilterOffline() {
        store.apply(.deviceAvailability(friendlyName: "Office Sensor", available: false))
        vm.statusFilter = .offline
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].friendlyName, "Office Sensor")
    }

    @MainActor
    func testFilterUpdatesAvailable() {
        store.apply(.deviceState(
            friendlyName: "Living Room Light",
            state: StateFixture.withOTA(state: "available", installed: 1, latest: 2)
        ))
        vm.statusFilter = .updatesAvailable
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].friendlyName, "Living Room Light")
    }

    @MainActor
    func testFilterBatteryLow() {
        store.apply(.deviceState(
            friendlyName: "Office Sensor",
            state: StateFixture.batteryLow(level: 5)
        ))
        vm.statusFilter = .batteryLow
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.contains { $0.friendlyName == "Office Sensor" })
    }

    @MainActor
    func testFilterWeakSignal() {
        store.apply(.deviceState(
            friendlyName: "Bedroom Thermostat",
            state: StateFixture.weakSignal(lqi: 10)
        ))
        vm.statusFilter = .weakSignal
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.contains { $0.friendlyName == "Bedroom Thermostat" })
    }

    @MainActor
    func testFilterInterviewing() {
        let interviewing = Device(
            ieeeAddress: "0xinterview", type: .endDevice, networkAddress: 99999,
            supported: true, friendlyName: "Interviewing Dev", disabled: false,
            description: nil, definition: nil, powerSource: "Battery",
            modelId: nil, manufacturer: nil,
            interviewCompleted: false, interviewing: true,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        store.apply(.devices(DeviceFixture.allCategoryDevices + [interviewing]))
        vm.statusFilter = .interviewing
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].friendlyName, "Interviewing Dev")
    }

    @MainActor
    func testFilterUnsupported() {
        let unsupported = Device(
            ieeeAddress: "0xunsup", type: .endDevice, networkAddress: 99998,
            supported: false, friendlyName: "Mystery Box", disabled: false,
            description: nil, definition: nil, powerSource: "Battery",
            modelId: nil, manufacturer: nil,
            interviewCompleted: true, interviewing: false,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        store.apply(.devices(DeviceFixture.allCategoryDevices + [unsupported]))
        vm.statusFilter = .unsupported
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].friendlyName, "Mystery Box")
    }

    // MARK: - Category filter

    @MainActor
    func testFilterByLightCategory() {
        vm.categoryFilter = .light
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.category == .light })
        XCTAssertFalse(result.isEmpty)
    }

    @MainActor
    func testFilterBySensorCategory() {
        vm.categoryFilter = .sensor
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.category == .sensor })
    }

    @MainActor
    func testFilterByClimateCategory() {
        vm.categoryFilter = .climate
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.category == .climate })
    }

    // MARK: - Vendor filter

    @MainActor
    func testFilterByVendor() {
        vm.vendorFilter = "IKEA"
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.definition?.vendor == "IKEA" })
    }

    // MARK: - Type (role) filter

    @MainActor
    func testFilterByRouter() {
        vm.typeFilter = .router
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.type == .router })
    }

    @MainActor
    func testFilterByEndDevice() {
        vm.typeFilter = .endDevice
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.type == .endDevice })
    }

    // MARK: - Coordinator is always excluded

    @MainActor
    func testCoordinatorExcluded() {
        store.apply(.devices(DeviceFixture.allCategoryDevices + [DeviceFixture.coordinator()]))
        let result = vm.filteredDevices(store: store)
        XCTAssertFalse(result.contains { $0.type == .coordinator })
    }

    // MARK: - Search

    @MainActor
    func testSearchByFriendlyName() {
        vm.searchText = "living"
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy { $0.friendlyName.lowercased().contains("living") })
    }

    @MainActor
    func testSearchByVendor() {
        vm.searchText = "ikea"
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.allSatisfy {
            $0.definition?.vendor.lowercased().contains("ikea") == true
        })
    }

    @MainActor
    func testSearchByModel() {
        vm.searchText = "SPZB"
        let result = vm.filteredDevices(store: store)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy {
            $0.definition?.model.lowercased().contains("spzb") == true
        })
    }

    @MainActor
    func testSearchEmpty_returnsAll() {
        vm.searchText = ""
        let result = vm.filteredDevices(store: store)
        XCTAssertEqual(result.count, DeviceFixture.allCategoryDevices.count)
    }

    @MainActor
    func testSearchNoMatch_returnsEmpty() {
        vm.searchText = "XXXXXX_NO_MATCH"
        let result = vm.filteredDevices(store: store)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Sorting

    @MainActor
    func testSortByNameAscending() {
        vm.sortOrder = .name
        vm.sortAscending = true
        let result = vm.filteredDevices(store: store)
        let names = result.map(\.friendlyName)
        XCTAssertEqual(names, names.sorted())
    }

    @MainActor
    func testSortByNameDescending() {
        vm.sortOrder = .name
        vm.sortAscending = false
        let result = vm.filteredDevices(store: store)
        let names = result.map(\.friendlyName)
        XCTAssertEqual(names, names.sorted(by: >))
    }

    @MainActor
    func testSortByBatteryAscending() {
        store.apply(.deviceState(friendlyName: "Living Room Light",
                                 state: ["battery": .int(10), "linkquality": .int(100)]))
        store.apply(.deviceState(friendlyName: "Office Sensor",
                                 state: ["battery": .int(90), "linkquality": .int(100)]))
        vm.sortOrder = .battery
        vm.sortAscending = true
        vm.categoryFilter = .light
        let result = vm.filteredDevices(store: store)
        XCTAssertFalse(result.isEmpty)
    }

    @MainActor
    func testSortByLinkQualityAscending() {
        store.apply(.deviceState(friendlyName: "Living Room Light",
                                 state: ["linkquality": .int(50)]))
        store.apply(.deviceState(friendlyName: "Bedroom Hue",
                                 state: ["linkquality": .int(200)]))
        vm.sortOrder = .linkQuality
        vm.sortAscending = true
        vm.categoryFilter = .light
        let result = vm.filteredDevices(store: store)
        guard result.count >= 2 else { return }
        let lqiFirst = store.state(for: result[0].friendlyName).linkQuality ?? -1
        let lqiSecond = store.state(for: result[1].friendlyName).linkQuality ?? -1
        XCTAssertGreaterThanOrEqual(lqiFirst, lqiSecond)
    }

    // MARK: - hasActiveFilter

    @MainActor
    func testHasActiveFilterFalseByDefault() {
        XCTAssertFalse(vm.hasActiveFilter)
    }

    @MainActor
    func testHasActiveFilterTrueWhenCategorySet() {
        vm.categoryFilter = .light
        XCTAssertTrue(vm.hasActiveFilter)
    }

    @MainActor
    func testHasActiveFilterTrueWhenStatusSet() {
        vm.statusFilter = .offline
        XCTAssertTrue(vm.hasActiveFilter)
    }

    // MARK: - applyQuickFilter

    @MainActor
    func testApplyQuickFilterOnline() {
        vm.applyQuickFilter(.online)
        XCTAssertEqual(vm.statusFilter, .online)
    }

    @MainActor
    func testApplyQuickFilterRouter() {
        vm.applyQuickFilter(.router)
        XCTAssertEqual(vm.typeFilter, .router)
    }

    @MainActor
    func testApplyQuickFilterAll() {
        vm.statusFilter = .offline
        vm.typeFilter = .router
        vm.applyQuickFilter(.all)
        XCTAssertEqual(vm.statusFilter, .all)
        XCTAssertNil(vm.typeFilter)
    }
}
