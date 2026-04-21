import Foundation
import UIKit
import SwiftUI

enum DeviceFilter: Hashable {
    case all
    case category(Device.Category)
    case updatesAvailable
    case offline
    case batteryLow
    case weakSignal
    case interviewing
    case unsupported

    var label: String {
        switch self {
        case .all:              return "All"
        case .category(let c): return c.label
        case .updatesAvailable: return "Updates"
        case .offline:          return "Offline"
        case .batteryLow:       return "Low Battery"
        case .weakSignal:       return "Bad Signal"
        case .interviewing:     return "Interviewing"
        case .unsupported:      return "Unsupported"
        }
    }

    var systemImage: String {
        switch self {
        case .all:              return "square.grid.2x2"
        case .category(let c): return c.systemImage
        case .updatesAvailable: return "arrow.down.circle.fill"
        case .offline:          return "wifi.slash"
        case .batteryLow:       return "battery.25"
        case .weakSignal:       return "wifi.exclamationmark"
        case .interviewing:     return "waveform.path.ecg"
        case .unsupported:      return "exclamationmark.triangle.fill"
        }
    }
}

enum DeviceSortOrder: String, CaseIterable {
    case name        = "Name"
    case lastSeen    = "Last Seen"
    case linkQuality = "Link Quality"
    case battery     = "Battery"
}

enum DeviceStatusFilter: String, CaseIterable, Hashable {
    case all              = "All"
    case online           = "Online"
    case offline          = "Offline"
    case updatesAvailable = "Updates Available"
    case batteryLow       = "Low Battery"
    case weakSignal       = "Bad Signal"
    case interviewing     = "Interviewing"
    case unsupported      = "Unsupported"

    var systemImage: String {
        switch self {
        case .all:              return "circle.grid.2x2"
        case .online:           return "wifi"
        case .offline:          return "wifi.slash"
        case .updatesAvailable: return "arrow.down.circle"
        case .batteryLow:       return "battery.25"
        case .weakSignal:       return "wifi.exclamationmark"
        case .interviewing:     return "waveform.path.ecg"
        case .unsupported:      return "exclamationmark.triangle"
        }
    }

    var condition: DeviceCondition? {
        switch self {
        case .all:              return nil
        case .online:           return .online
        case .offline:          return .offline
        case .updatesAvailable: return .updatesAvailable
        case .batteryLow:       return .batteryLow
        case .weakSignal:       return .weakSignal
        case .interviewing:     return .interviewing
        case .unsupported:      return .unsupported
        }
    }
}

@Observable
final class DeviceListViewModel {
    var searchText     = ""
    var categoryFilter: Device.Category? = nil
    var typeFilter: DeviceType? = nil
    var vendorFilter: String? = nil
    var statusFilter: DeviceStatusFilter = .all
    var sortOrder: DeviceSortOrder = .name
    var sortAscending = true

    var hasActiveFilter: Bool {
        categoryFilter != nil || typeFilter != nil || vendorFilter != nil || statusFilter != .all
    }

    func filteredDevices(store: AppStore) -> [Device] {
        var devices = crossBase(store, excludingStatus: false, excludingCategory: false, excludingVendor: false)

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            devices = devices.filter { d in
                d.friendlyName.lowercased().contains(q)
                || d.description?.lowercased().contains(q) == true
                || d.definition?.vendor.lowercased().contains(q) == true
                || d.definition?.model.lowercased().contains(q) == true
            }
        }

        return sorted(devices, store: store)
    }

    // MARK: - Cross-filter-aware counts

    func statusCount(for filter: DeviceStatusFilter, store: AppStore) -> Int {
        let base = crossBase(store, excludingStatus: true)
        guard let condition = filter.condition else { return base.count }
        return base.filter {
            condition.matches(
                device: $0,
                state: store.state(for: $0.friendlyName),
                isAvailable: store.isAvailable($0.friendlyName)
            )
        }.count
    }

    func typeCount(for category: Device.Category, store: AppStore) -> Int {
        crossBase(store, excludingCategory: true).filter { $0.category == category }.count
    }

    func vendorCount(for vendor: String, store: AppStore) -> Int {
        crossBase(store, excludingVendor: true).filter { $0.definition?.vendor == vendor }.count
    }

    func roleCount(for type: DeviceType, store: AppStore) -> Int {
        crossBase(store, excludingType: true).filter { $0.type == type }.count
    }

    // MARK: - Actions

    func applyQuickFilter(_ filter: DeviceQuickFilter) {
        typeFilter = nil
        statusFilter = .all
        switch filter {
        case .all:              break
        case .online:           statusFilter = .online
        case .offline:          statusFilter = .offline
        case .updatesAvailable: statusFilter = .updatesAvailable
        case .batteryLow:       statusFilter = .batteryLow
        case .weakSignal:       statusFilter = .weakSignal
        case .interviewing:     statusFilter = .interviewing
        case .unsupported:      statusFilter = .unsupported
        case .router:           typeFilter = .router
        case .endDevice:        typeFilter = .endDevice
        }
    }

    func updateDevice(_ device: Device, environment: AppEnvironment) {
        Haptics.impact(.medium)
        environment.store.startOTAUpdate(for: device.friendlyName)
        environment.send(
            topic: Z2MTopics.Request.deviceOTAUpdate,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    func checkDeviceUpdate(_ device: Device, environment: AppEnvironment) {
        Haptics.impact(.light)
        environment.store.startOTACheck(for: device.friendlyName)
        environment.send(
            topic: Z2MTopics.Request.deviceOTACheck,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    func renameDevice(_ device: Device, to newName: String, homeassistantRename: Bool = true, environment: AppEnvironment) {
        environment.send(topic: "bridge/request/device/rename", payload: .object([
            "from": .string(device.friendlyName),
            "to": .string(newName),
            "homeassistant_rename": .bool(homeassistantRename)
        ]))
    }

    func reconfigureDevice(_ device: Device, environment: AppEnvironment) {
        environment.send(topic: "bridge/request/device/configure", payload: .object(["id": .string(device.friendlyName)]))
    }

    func interviewDevice(_ device: Device, environment: AppEnvironment) {
        environment.send(topic: "bridge/request/device/interview", payload: .object(["id": .string(device.friendlyName)]))
    }

    func removeDevice(_ device: Device, force: Bool = false, block: Bool = false, environment: AppEnvironment) {
        environment.send(topic: "bridge/request/device/remove", payload: .object([
            "id": .string(device.friendlyName),
            "force": .bool(force),
            "block": .bool(block)
        ]))
    }

    // MARK: - Private helpers

    private func crossBase(
        _ store: AppStore,
        excludingStatus: Bool = false,
        excludingCategory: Bool = false,
        excludingVendor: Bool = false,
        excludingType: Bool = false
    ) -> [Device] {
        var d = store.devices.filter { $0.type != .coordinator }
        if !excludingStatus   { d = applyStatus(statusFilter, to: d, store: store) }
        if !excludingCategory, let cat = categoryFilter { d = d.filter { $0.category == cat } }
        if !excludingVendor,   let ven = vendorFilter   { d = d.filter { $0.definition?.vendor == ven } }
        if !excludingType,     let typ = typeFilter     { d = d.filter { $0.type == typ } }
        return d
    }

    private func applyStatus(_ filter: DeviceStatusFilter, to devices: [Device], store: AppStore) -> [Device] {
        guard let condition = filter.condition else { return devices }
        return devices.filter {
            condition.matches(
                device: $0,
                state: store.state(for: $0.friendlyName),
                isAvailable: store.isAvailable($0.friendlyName)
            )
        }
    }

    private func sorted(_ devices: [Device], store: AppStore) -> [Device] {
        devices.sorted { a, b in
            switch sortOrder {
            case .name:
                return sortAscending
                    ? a.friendlyName.localizedCompare(b.friendlyName) == .orderedAscending
                    : a.friendlyName.localizedCompare(b.friendlyName) == .orderedDescending
            case .linkQuality:
                let aLQI = store.state(for: a.friendlyName).linkQuality ?? -1
                let bLQI = store.state(for: b.friendlyName).linkQuality ?? -1
                return sortAscending ? aLQI > bLQI : aLQI < bLQI
            case .battery:
                let aBatt = store.state(for: a.friendlyName).battery ?? 101
                let bBatt = store.state(for: b.friendlyName).battery ?? 101
                return sortAscending ? aBatt < bBatt : aBatt > bBatt
            case .lastSeen:
                return sortAscending
                    ? a.friendlyName.localizedCompare(b.friendlyName) == .orderedAscending
                    : a.friendlyName.localizedCompare(b.friendlyName) == .orderedDescending
            }
        }
    }
}
