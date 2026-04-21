import Foundation

struct HomeStatsSnapshot: Sendable {
    let deviceTypeItems: [HomeStatsCount]
    let powerSourceItems: [HomeStatsCount]
    let vendorItems: [HomeStatsCount]
    let modelItems: [HomeStatsCount]

    init(devices: [Device]) {
        let nonCoordinatorDevices = devices.filter { $0.type != .coordinator }

        deviceTypeItems = Self.counts(
            for: nonCoordinatorDevices.map(Self.deviceTypeLabel),
            limit: Limits.deviceTypes
        )
        powerSourceItems = Self.counts(
            for: nonCoordinatorDevices.map(Self.powerSourceLabel),
            limit: Limits.powerSources
        )
        vendorItems = Self.counts(
            for: nonCoordinatorDevices.map(Self.vendorLabel),
            limit: Limits.vendors
        )
        modelItems = Self.counts(
            for: nonCoordinatorDevices.map(Self.modelLabel),
            limit: Limits.models
        )
    }

    private enum Limits {
        static let deviceTypes = 4
        static let powerSources = 4
        static let vendors = 6
        static let models = 6
    }

    private static func counts(for values: [String], limit: Int) -> [HomeStatsCount] {
        var countsByTitle: [String: Int] = [:]
        for value in values {
            countsByTitle[value, default: 0] += 1
        }

        let unsortedItems = countsByTitle.map { title, count in
            HomeStatsCount(title: title, count: count)
        }
        let sorted = unsortedItems.sorted(by: Self.sortCounts)

        guard sorted.count > limit else { return sorted }

        let visible = Array(sorted.prefix(limit))
        let others = sorted.dropFirst(limit).reduce(0) { partialResult, item in
            partialResult + item.count
        }
        return visible + [HomeStatsCount(title: "Others", count: others)]
    }

    private static func sortCounts(_ lhs: HomeStatsCount, _ rhs: HomeStatsCount) -> Bool {
        if lhs.count == rhs.count {
            return lhs.title < rhs.title
        }
        return lhs.count > rhs.count
    }

    private static func deviceTypeLabel(_ device: Device) -> String {
        switch device.type {
        case .router:
            return "Routers"
        case .endDevice:
            return "End Devices"
        case .unknown:
            return "Unknown Type"
        case .coordinator:
            return "Coordinator"
        }
    }

    private static func powerSourceLabel(_ device: Device) -> String {
        guard let powerSource = device.powerSource?.trimmingCharacters(in: .whitespacesAndNewlines),
              !powerSource.isEmpty else {
            return "Unknown"
        }

        let normalized = powerSource.lowercased()
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("mains") || normalized.contains("ac") || normalized.contains("dc") {
            return "Mains"
        }
        return powerSource.capitalized
    }

    private static func vendorLabel(_ device: Device) -> String {
        device.definition?.vendor ?? device.manufacturer ?? "Unknown Vendor"
    }

    private static func modelLabel(_ device: Device) -> String {
        device.definition?.model ?? device.modelId ?? "Unknown Model"
    }
}

struct HomeStatsCount: Identifiable, Sendable {
    let title: String
    let count: Int

    var id: String { title }

    init(title: String, count: Int) {
        self.title = title
        self.count = count
    }

    init(title: String, value: Int) {
        self.init(title: title, count: value)
    }
}
