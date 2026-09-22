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
    /// Oldest `last_seen` among devices that are currently unreachable. Drives
    /// the caption under the Offline figure — "3h+ quiet" says more than "7".
    let oldestOfflineLastSeen: Date?
    /// Worst battery level among the devices below the low-battery threshold.
    let lowestBatteryLevel: Int?
    /// Worst link quality among the devices below the weak-signal threshold.
    let weakestLinkQuality: Int?
    let bridgeVersion: String?
    let bridgeCommit: String?
    let coordinatorType: String?
    let coordinatorIEEEAddress: String?
    let networkChannel: Int?
    let panID: Int?
    let isPermitJoinActive: Bool
    let permitJoinRemaining: Int?
    let restartRequired: Bool

    // MARK: - Captions
    //
    // Only ever derived from data. A cell gets a caption when there is
    // something true to say under it and none otherwise — no filler.

    var offlineCaption: String? {
        guard offlineDevices > 0, let oldestOfflineLastSeen else { return nil }
        return "\(Self.compactDuration(since: oldestOfflineLastSeen)) quiet"
    }

    var lowBatteryCaption: String? {
        guard let lowestBatteryLevel else { return nil }
        return "lowest \(lowestBatteryLevel)%"
    }

    var weakSignalCaption: String? {
        guard let weakestLinkQuality else { return nil }
        return "lowest \(weakestLinkQuality)"
    }

    // MARK: - Calm
    //
    // Home collapses a card that has nothing to report. Firmware updates are
    // deliberately excluded: an update waiting is news, not trouble, so it
    // rides along in the collapsed line instead of forcing the card open.

    var deviceAttentionCount: Int {
        offlineDevices + lowBatteryDevices + weakSignalDevices
    }

    var devicesAreCalm: Bool { deviceAttentionCount == 0 }

    /// Permit join and interviews are deliberately absent: the pinned "right
    /// now" card owns everything in flight, and reporting it here too would
    /// say the same thing twice.
    var networkIsCalm: Bool {
        isConnected && isBridgeOnline && !restartRequired
    }

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

        let offlineNames = nonCoordinatorDevices.filter {
            $0.availabilityTrackingEnabled && availability[$0.friendlyName] != true
        }.map(\.friendlyName)
        oldestOfflineLastSeen = offlineNames.compactMap { states[$0]?.lastSeen }.min()

        let lowBatteryLevels = nonCoordinatorDevices.compactMap { device -> Int? in
            guard let battery = (states[device.friendlyName] ?? [:]).battery,
                  DesignTokens.Threshold.isLowBattery(battery) else { return nil }
            return battery
        }
        lowestBatteryLevel = lowBatteryLevels.min()

        let weakSignals = nonCoordinatorDevices.compactMap { device -> Int? in
            guard let quality = (states[device.friendlyName] ?? [:]).linkQuality,
                  quality < DesignTokens.Threshold.weakSignal else { return nil }
            return quality
        }
        weakestLinkQuality = weakSignals.min()

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

    /// "12m+", "3h+", "2d+" — short enough to sit under a figure in a
    /// three-across stat row.
    static func compactDuration(since date: Date, now: Date = Date()) -> String {
        let seconds = max(Int(now.timeIntervalSince(date)), 0)
        if seconds < 3_600 { return "\(max(seconds / 60, 1))m+" }
        if seconds < 86_400 { return "\(seconds / 3_600)h+" }
        return "\(seconds / 86_400)d+"
    }

    private static func permitJoinRemaining(from end: Int?) -> Int? {
        guard let end else { return nil }
        let now = Int(Date().timeIntervalSince1970 * 1000)
        return max((end - now) / 1000, 0)
    }
}
