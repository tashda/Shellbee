import Foundation

struct HomeSnapshot: Sendable {
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
            return battery <= DesignTokens.Threshold.lowBattery
        }.count
        weakSignalDevices = nonCoordinatorDevices.filter {
            guard let quality = (states[$0.friendlyName] ?? [:]).linkQuality else { return false }
            return quality < DesignTokens.Threshold.weakSignal
        }.count
        interviewingDevices = nonCoordinatorDevices.filter { $0.isInterviewing }.count
        let lqiValues = nonCoordinatorDevices.compactMap { states[$0.friendlyName]?.linkQuality }
        averageLinkQuality = lqiValues.isEmpty ? nil : lqiValues.reduce(0, +) / lqiValues.count

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

    private static func permitJoinRemaining(from end: Int?) -> Int? {
        guard let end else { return nil }
        let now = Int(Date().timeIntervalSince1970 * 1000)
        return max((end - now) / 1000, 0)
    }
}
