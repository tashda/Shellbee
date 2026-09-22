import Foundation

struct HomeSnapshot: Sendable {
    struct LinkQualityBand: Identifiable, Sendable {
        /// Lower bound of the band, inclusive.
        let lowerBound: Int
        /// Upper bound, exclusive. `nil` on the open-ended top band.
        let upperBound: Int?
        let count: Int

        var id: Int { lowerBound }

        var label: String {
            guard let upperBound else { return "\(lowerBound)+" }
            return "\(lowerBound)–\(upperBound)"
        }

        /// The band worth acting on. Matches the weak-signal threshold the
        /// rest of the app filters by.
        var needsAttention: Bool { (upperBound ?? Int.max) <= DesignTokens.Threshold.weakSignal }
    }

    struct BatteryReading: Identifiable, Sendable {
        let name: String
        let percent: Int

        var id: String { name }
        var isLow: Bool { DesignTokens.Threshold.isLowBattery(percent) }
    }

    let isConnected: Bool
    let isBridgeOnline: Bool
    let totalDevices: Int
    let onlineDevices: Int
    let offlineDevices: Int
    let availabilityOffDevices: Int
    let routerCount: Int
    let endDeviceCount: Int
    let unsupportedDevices: Int
    let disabledDevices: Int
    let groupCount: Int
    let devicesWithUpdates: Int
    let scheduledUpdateDevices: Int
    let updatingDevices: Int
    let lowBatteryDevices: Int
    let weakSignalDevices: Int
    let interviewingDevices: Int
    let averageLinkQuality: Int?
    /// How many devices fall in each link-quality band, weakest first.
    /// The Link quality card draws these; the average alone hides whether
    /// a mesh is evenly good or bimodal with a corner barely hanging on.
    let linkQualityBands: [LinkQualityBand]
    /// Battery-powered devices, emptiest first. The attention row says how
    /// many are low; this says which, and what is next in line.
    let batteryReadings: [BatteryReading]
    let bridgeVersion: String?
    let bridgeCommit: String?
    let coordinatorType: String?
    let coordinatorIEEEAddress: String?
    let networkChannel: Int?
    let panID: Int?
    let isPermitJoinActive: Bool
    let permitJoinRemaining: Int?
    let restartRequired: Bool

    var releaseURL: URL? {
        guard let bridgeVersion else { return nil }
        return URL(string: "https://github.com/Koenkk/zigbee2mqtt/releases/tag/\(bridgeVersion)")
    }

    var coordinatorSuffix: String? {
        guard let coordinatorIEEEAddress else { return nil }
        return String(coordinatorIEEEAddress.suffix(6)).uppercased()
    }

    var panIDText: String? {
        guard let panID else { return nil }
        return String(format: "PAN 0x%04X", panID)
    }

    init(
        devices: [Device],
        availability: [String: Bool],
        states: [String: [String: JSONValue]],
        otaStatuses: [String: OTAUpdateStatus] = [:],
        isConnected: Bool,
        isBridgeOnline: Bool,
        groupCount: Int,
        bridgeVersion: String?,
        bridgeCommit: String?,
        coordinatorType: String?,
        coordinatorIEEEAddress: String?,
        networkChannel: Int?,
        panID: Int?,
        isPermitJoinActive: Bool,
        permitJoinEnd: Int?,
        restartRequired: Bool
    ) {
        let nonCoordinatorDevices = devices.filter { $0.type != .coordinator }

        totalDevices = nonCoordinatorDevices.count
        onlineDevices = nonCoordinatorDevices.filter {
            $0.availabilityTrackingEnabled
                && availability[$0.friendlyName] == true
        }.count
        offlineDevices = nonCoordinatorDevices.filter {
            $0.availabilityTrackingEnabled
                && availability[$0.friendlyName] != true
        }.count
        availabilityOffDevices = nonCoordinatorDevices.filter {
            !$0.availabilityTrackingEnabled
        }.count
        routerCount = nonCoordinatorDevices.filter { $0.type == .router }.count
        endDeviceCount = nonCoordinatorDevices.filter { $0.type == .endDevice }.count
        unsupportedDevices = nonCoordinatorDevices.filter { !$0.supported }.count
        disabledDevices = nonCoordinatorDevices.filter { $0.disabled }.count
        self.groupCount = groupCount
        devicesWithUpdates = nonCoordinatorDevices.filter {
            (states[$0.friendlyName] ?? [:]).hasUpdateAvailable
        }.count
        scheduledUpdateDevices = nonCoordinatorDevices.filter {
            let phase = otaStatuses[$0.friendlyName]?.phase
                ?? OTAUpdateStatus.Phase(rawValue: (states[$0.friendlyName] ?? [:]).otaUpdateState ?? "")
            return phase == .scheduled
        }.count
        updatingDevices = nonCoordinatorDevices.filter {
            if otaStatuses[$0.friendlyName]?.phase == .updating { return true }
            return (states[$0.friendlyName] ?? [:]).isUpdating
        }.count
        lowBatteryDevices = nonCoordinatorDevices.filter {
            guard let battery = (states[$0.friendlyName] ?? [:]).battery else { return false }
            return DesignTokens.Threshold.isLowBattery(battery)
        }.count
        weakSignalDevices = nonCoordinatorDevices.filter {
            guard let quality = (states[$0.friendlyName] ?? [:]).linkQuality else { return false }
            return quality < DesignTokens.Threshold.weakSignal
        }.count
        interviewingDevices = nonCoordinatorDevices.filter { $0.isInterviewing }.count
        let lqiValues = nonCoordinatorDevices.compactMap { states[$0.friendlyName]?.linkQuality }
        averageLinkQuality = lqiValues.isEmpty ? nil : lqiValues.reduce(0, +) / lqiValues.count
        linkQualityBands = Self.bands(for: lqiValues)
        batteryReadings = nonCoordinatorDevices
            .compactMap { device in
                guard let percent = (states[device.friendlyName] ?? [:]).battery else { return nil }
                return BatteryReading(name: device.friendlyName, percent: percent)
            }
            .sorted { ($0.percent, $0.name) < ($1.percent, $1.name) }

        self.isConnected = isConnected
        self.isBridgeOnline = isBridgeOnline
        self.bridgeVersion = bridgeVersion
        self.bridgeCommit = bridgeCommit
        self.coordinatorType = coordinatorType
        self.coordinatorIEEEAddress = coordinatorIEEEAddress
        self.networkChannel = networkChannel
        self.panID = panID
        self.isPermitJoinActive = isPermitJoinActive
        self.permitJoinRemaining = Self.permitJoinRemaining(from: permitJoinEnd)
        self.restartRequired = restartRequired
    }

    /// Five bands wide enough to read on a phone, narrow enough to show a
    /// bimodal mesh for what it is.
    private static func bands(for values: [Int]) -> [LinkQualityBand] {
        guard !values.isEmpty else { return [] }
        let edges = [0, 50, 100, 150, 200]
        return edges.enumerated().map { index, lower in
            let upper = index + 1 < edges.count ? edges[index + 1] : nil
            let count = values.filter { value in
                guard let upper else { return value >= lower }
                return value >= lower && value < upper
            }.count
            return LinkQualityBand(lowerBound: lower, upperBound: upper, count: count)
        }
    }

    private static func permitJoinRemaining(from end: Int?) -> Int? {
        guard let end else { return nil }
        let now = Int(Date().timeIntervalSince1970 * 1000)
        return max((end - now) / 1000, 0)
    }
}

extension HomeSnapshot {
    /// A small network with something wrong on it, for previews and tests:
    /// two devices not answering, one flat battery, one weak link and one
    /// firmware update waiting. Built from real devices and states so it
    /// runs the same arithmetic the app does.
    static var preview: HomeSnapshot {
        func device(_ name: String, _ type: DeviceType = .router) -> Device {
            Device(
                ieeeAddress: "0x\(abs(name.hashValue))",
                type: type,
                networkAddress: abs(name.hashValue % 60_000),
                supported: true,
                friendlyName: name,
                disabled: false,
                interviewCompleted: true,
                interviewing: false
            )
        }

        let devices = [
            device("hallway_plug"),
            device("bathroom_ff_spot_1"),
            device("kitchen_relay"),
            device("office_door_sensor", .endDevice),
            device("bedroom_remote", .endDevice),
        ]

        return HomeSnapshot(
            devices: devices,
            availability: [
                "hallway_plug": true,
                "bathroom_ff_spot_1": false,
                "kitchen_relay": false,
                "office_door_sensor": true,
                "bedroom_remote": true,
            ],
            states: [
                "hallway_plug": ["linkquality": .int(146)],
                "bathroom_ff_spot_1": ["linkquality": .int(28)],
                "office_door_sensor": ["battery": .int(9), "linkquality": .int(96)],
                "bedroom_remote": ["linkquality": .int(120),
                                   "update": .object(["state": .string("available")])],
            ],
            isConnected: true,
            isBridgeOnline: true,
            groupCount: 12,
            bridgeVersion: "2.9.2",
            bridgeCommit: nil,
            coordinatorType: "EmberZNet",
            coordinatorIEEEAddress: "0x4c5bb3fffe932a84",
            networkChannel: 20,
            panID: 54_074,
            isPermitJoinActive: false,
            permitJoinEnd: nil,
            restartRequired: false
        )
    }
}
