import Foundation
import UIKit

@Observable
final class AppStore {
    var devices: [Device] = []
    var groups: [Group] = []
    var bridgeInfo: BridgeInfo?
    var bridgeHealth: BridgeHealth?
    var bridgeOnline = false
    var isConnected = false
    var deviceStates: [String: [String: JSONValue]] = [:]
    var deviceAvailability: [String: Bool] = [:]
    // First-seen timestamps keyed by ieeeAddress. Drives the "Recently Added"
    // section in the device list and is persisted across launches so the
    // 30-minute window keeps counting while the app is closed.
    var deviceFirstSeen: [String: Date] = [:]
    // Optimistic renames awaiting bridge confirmation. Used to roll back if z2m
    // returns status="error" for the rename request.
    var pendingRenames: [(from: String, to: String)] = []
    // Friendly names of devices the user has asked to remove and we're awaiting
    // bridge/response/device/remove for. Drives the "Deleting" badge and
    // disables further swipe-deletes on the same row.
    var pendingRemovals: Set<String> = []
    private static let firstSeenStoreKey = "AppStore.deviceFirstSeen"
    var otaUpdates: [String: OTAUpdateStatus] = [:]
    var logEntries: [LogEntry] = []
    var rawLogEntries: [LogEntry] = []
    var operationErrors: [Z2MOperationError] = []
    var touchlinkDevices: [TouchlinkDevice] = []
    var touchlinkScanInProgress = false
    var touchlinkIdentifyInProgress = false
    var touchlinkResetInProgress = false
    /// Friendly names of devices currently running an Identify (Zigbee
    /// Identify cluster). The action is fire-and-forget, so the row clears
    /// itself on a short timer rather than waiting for a response.
    var identifyInProgress: Set<String> = []
    var pendingNotifications: [InAppNotification] = []
    var fastTrackNotifications: [InAppNotification] = []
    // Bumped whenever a new (non-coalesced) normal notification is enqueued.
    // The overlay observes this to fire the arrival haptic exactly once per
    // new banner, independent of coalescing bumps.
    var notificationArrivalID: UUID = UUID()

    // Set by AppEnvironment to route OTA check/update responses into the
    // bulk queue so it can advance to the next device.
    var otaResponseForwarding: ((_ friendlyName: String, _ success: Bool, _ kind: OTABulkOperationQueue.Kind) -> Void)?

    // One-shot callback invoked when the next bridge/response/backup arrives.
    // BackupView sets this before sending the request and clears it on receipt.
    // Tuple: (zipBase64, errorMessage) — exactly one is non-nil.
    var backupResponseHandler: ((_ zipBase64: String?, _ error: String?) -> Void)?

    // Set by AppEnvironment to filter out notifications the user disabled
    // in Settings → App → Notifications. Returns true to allow.
    var notificationFilter: ((InAppNotification) -> Bool)?

    // Transient per-device check results rendered briefly in the row after
    // "Checking" resolves. Cleared automatically after a short interval.
    var deviceCheckResults: [String: DeviceCheckResult] = [:]

    enum DeviceCheckResult: Equatable {
        case noUpdate
        case updateFound
        case failed
    }

    static let logLimit = 1000
    static let coalesceWindow: TimeInterval = AppConfig.UX.notificationCoalesceWindow

    init() {
        if let raw = UserDefaults.standard.dictionary(forKey: Self.firstSeenStoreKey) as? [String: Double] {
            deviceFirstSeen = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    func reset() {
        devices = []
        groups = []
        bridgeInfo = nil
        bridgeHealth = nil
        bridgeOnline = false
        isConnected = false
        deviceStates = [:]
        deviceAvailability = [:]
        pendingRenames = []
        deviceFirstSeen = [:]
        UserDefaults.standard.removeObject(forKey: Self.firstSeenStoreKey)
        otaUpdates = [:]
        logEntries = []
        operationErrors = []
        pendingNotifications = []
        fastTrackNotifications = []
        deviceCheckResults = [:]
        pendingRemovals = []
        touchlinkDevices = []
        touchlinkScanInProgress = false
        touchlinkIdentifyInProgress = false
        touchlinkResetInProgress = false
        identifyInProgress = []
        OTAUpdateLiveActivityCoordinator.shared.clearAll()
    }

    // MARK: - First-seen persistence

    private func persistFirstSeen() {
        let raw = deviceFirstSeen.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: Self.firstSeenStoreKey)
    }

    func recordFirstSeen(ieee: String, overwrite: Bool = false) {
        if !overwrite, deviceFirstSeen[ieee] != nil { return }
        deviceFirstSeen[ieee] = Date()
        persistFirstSeen()
    }

    func removeFirstSeen(ieee: String) {
        guard deviceFirstSeen.removeValue(forKey: ieee) != nil else { return }
        persistFirstSeen()
    }
}
