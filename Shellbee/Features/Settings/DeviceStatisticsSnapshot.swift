import Foundation

/// The bridge-scoped facts shown by the Device Statistics dashboard.
/// Coordinators are infrastructure, so the device totals match Home and the
/// Devices tab by excluding them.
struct DeviceStatisticsSnapshot: Sendable {
    struct Count: Identifiable, Sendable {
        let title: String
        let count: Int

        var id: String { title }
    }

    let totalDevices: Int
    let onlineDevices: Int
    let offlineDevices: Int
    let untrackedDevices: Int
    let supportedDevices: Int
    let batteryDevices: Int
    let devicesReportingLinkQuality: Int
    let averageLinkQuality: Int?
    private let linkQualityTotal: Int
    let deviceTypes: [Count]
    let powerSources: [Count]
    let vendors: [Count]
    let models: [Count]

    var availability: [Count] {
        [
            Count(title: "Online", count: onlineDevices),
            Count(title: "Offline", count: offlineDevices),
            Count(title: "Not tracked", count: untrackedDevices),
        ].filter { $0.count > 0 }
    }

    var distinctVendors: Int { vendors.count }
    var distinctModels: Int { models.count }

    init(
        devices: [Device],
        availability: [String: Bool],
        states: [String: [String: JSONValue]]
    ) {
        let devices = devices.filter { $0.type != .coordinator }
        let tracked = devices.filter(\.availabilityTrackingEnabled)
        let linkQualityValues = devices.compactMap { states[$0.friendlyName]?.linkQuality }

        totalDevices = devices.count
        onlineDevices = tracked.filter { availability[$0.friendlyName] == true }.count
        offlineDevices = tracked.filter { availability[$0.friendlyName] != true }.count
        untrackedDevices = devices.count - tracked.count
        supportedDevices = devices.filter(\.supported).count
        batteryDevices = devices.filter { Self.powerSourceLabel($0) == "Battery" }.count
        devicesReportingLinkQuality = linkQualityValues.count
        linkQualityTotal = linkQualityValues.reduce(0, +)
        averageLinkQuality = linkQualityValues.isEmpty
            ? nil
            : linkQualityTotal / linkQualityValues.count
        deviceTypes = Self.counts(devices.map(Self.deviceTypeLabel))
        powerSources = Self.counts(devices.map(Self.powerSourceLabel))
        vendors = Self.counts(devices.map(Self.vendorLabel))
        models = Self.counts(devices.map(Self.modelLabel))
    }

    /// Sum bridge-scoped snapshots so duplicate friendly names never share
    /// availability or state across bridges.
    init(merging snapshots: [DeviceStatisticsSnapshot]) {
        totalDevices = snapshots.reduce(0) { $0 + $1.totalDevices }
        onlineDevices = snapshots.reduce(0) { $0 + $1.onlineDevices }
        offlineDevices = snapshots.reduce(0) { $0 + $1.offlineDevices }
        untrackedDevices = snapshots.reduce(0) { $0 + $1.untrackedDevices }
        supportedDevices = snapshots.reduce(0) { $0 + $1.supportedDevices }
        batteryDevices = snapshots.reduce(0) { $0 + $1.batteryDevices }
        devicesReportingLinkQuality = snapshots.reduce(0) { $0 + $1.devicesReportingLinkQuality }
        linkQualityTotal = snapshots.reduce(0) { $0 + $1.linkQualityTotal }
        averageLinkQuality = devicesReportingLinkQuality == 0
            ? nil : linkQualityTotal / devicesReportingLinkQuality
        deviceTypes = Self.mergeCounts(snapshots.flatMap(\.deviceTypes))
        powerSources = Self.mergeCounts(snapshots.flatMap(\.powerSources))
        vendors = Self.mergeCounts(snapshots.flatMap(\.vendors))
        models = Self.mergeCounts(snapshots.flatMap(\.models))
    }

    private static func mergeCounts(_ counts: [Count]) -> [Count] {
        Dictionary(grouping: counts, by: \.title)
            .map { Count(title: $0.key, count: $0.value.reduce(0) { $0 + $1.count }) }
            .sorted {
                if $0.count == $1.count { return $0.title < $1.title }
                return $0.count > $1.count
            }
    }

    private static func counts(_ values: [String]) -> [Count] {
        Dictionary(grouping: values, by: { $0 })
            .map { Count(title: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count { return $0.title < $1.title }
                return $0.count > $1.count
            }
    }

    private static func deviceTypeLabel(_ device: Device) -> String {
        switch device.type {
        case .router: "Routers"
        case .endDevice: "End devices"
        case .unknown: "Unknown type"
        case .coordinator: "Coordinator"
        }
    }

    private static func powerSourceLabel(_ device: Device) -> String {
        guard let raw = device.powerSource?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return "Unknown"
        }

        let normalized = raw.lowercased()
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("mains") || normalized.contains("ac") || normalized.contains("dc") {
            return "Mains"
        }
        return raw.capitalized
    }

    private static func vendorLabel(_ device: Device) -> String {
        device.definition?.vendor ?? device.manufacturer ?? "Unknown vendor"
    }

    private static func modelLabel(_ device: Device) -> String {
        device.definition?.model ?? device.modelId ?? "Unknown model"
    }
}
