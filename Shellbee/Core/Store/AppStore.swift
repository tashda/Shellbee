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
    /// First-seen timestamps for the *active* bridge, keyed by ieeeAddress.
    /// Drives the "Recently Added" section in the device list. Persisted
    /// per-bridge under `AppStore.deviceFirstSeenByBridge` so the same IEEE
    /// can have independent first-seen times across bridges (a real concern:
    /// the same device model exists on multiple Z2M networks).
    private(set) var deviceFirstSeen: [String: Date] = [:]
    // Optimistic renames awaiting bridge confirmation. Used to roll back if z2m
    // returns status="error" for the rename request.
    var pendingRenames: [(from: String, to: String)] = []
    // Friendly names of devices the user has asked to remove and we're awaiting
    // bridge/response/device/remove for. Drives the "Deleting" badge and
    // disables further swipe-deletes on the same row.
    var pendingRemovals: Set<String> = []
    /// Per-bridge first-seen storage. Keyed by `ConnectionConfig.id`. The
    /// active bridge's slot is mirrored to `deviceFirstSeen` so existing
    /// read sites continue to work without a bridgeID parameter.
    private var firstSeenByBridge: [UUID: [String: Date]] = [:]
    /// The currently-active bridge id, set by `ConnectionSessionController` on
    /// successful connect. While nil (idle / pre-first-connect), first-seen
    /// mutations are silently dropped — there's no bridge to attribute them to.
    private(set) var activeBridgeID: UUID?
    private static let firstSeenStoreKey = "AppStore.deviceFirstSeen"
    private static let firstSeenByBridgeStoreKey = "AppStore.deviceFirstSeenByBridge"
    /// Legacy first-seen data loaded from the pre-multi-bridge format. Migrated
    /// into `firstSeenByBridge` under the first bridge id we see via
    /// `setActiveBridge(_:)` and then cleared.
    private var pendingLegacyFirstSeen: [String: Date]?
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
        loadFirstSeen()
    }

    /// Clears all bridge-scoped state in preparation for a fresh connection
    /// (either a switch or a reconnect). `deviceFirstSeen` is preserved per
    /// bridge in `firstSeenByBridge` and re-mirrored when `setActiveBridge`
    /// runs.
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
        // `deviceFirstSeen` itself is rebuilt by `setActiveBridge` after the
        // next successful connect — so we clear the published mirror here so
        // the UI doesn't briefly show the prior bridge's "Recently Added"
        // entries while reconnecting.
        deviceFirstSeen = [:]
        OTAUpdateLiveActivityCoordinator.shared.clearAll()
    }

    // MARK: - Active bridge tracking

    /// Called by the session controller after a successful connection. Loads
    /// this bridge's first-seen slot into the published `deviceFirstSeen`
    /// mirror, and migrates any pending legacy data into this bridge's slot.
    func setActiveBridge(_ id: UUID) {
        if let legacy = pendingLegacyFirstSeen, !legacy.isEmpty {
            // Merge legacy data under this bridge — first connect after upgrade
            // attributes everything to whichever bridge the user reached first.
            firstSeenByBridge[id, default: [:]].merge(legacy) { existing, _ in existing }
            pendingLegacyFirstSeen = nil
            persistFirstSeen()
        }
        activeBridgeID = id
        deviceFirstSeen = firstSeenByBridge[id] ?? [:]
    }

    /// Called on disconnect (not on simple reconnect). Clears the active
    /// pointer; the published mirror has already been cleared by `reset`.
    func clearActiveBridge() {
        activeBridgeID = nil
    }

    // MARK: - First-seen persistence

    private func loadFirstSeen() {
        // Prefer the new partitioned format.
        if let data = UserDefaults.standard.data(forKey: Self.firstSeenByBridgeStoreKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            for (key, ieeeMap) in decoded {
                guard let id = UUID(uuidString: key) else { continue }
                firstSeenByBridge[id] = ieeeMap.mapValues { Date(timeIntervalSince1970: $0) }
            }
            return
        }

        // Fall back to legacy format. Stash it for migration into whichever
        // bridge becomes active first.
        if let raw = UserDefaults.standard.dictionary(forKey: Self.firstSeenStoreKey) as? [String: Double] {
            pendingLegacyFirstSeen = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    private func persistFirstSeen() {
        let encodable: [String: [String: Double]] = firstSeenByBridge.reduce(into: [:]) { acc, entry in
            acc[entry.key.uuidString] = entry.value.mapValues { $0.timeIntervalSince1970 }
        }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        UserDefaults.standard.set(data, forKey: Self.firstSeenByBridgeStoreKey)
        // Drop the legacy key now that we've written the new format.
        UserDefaults.standard.removeObject(forKey: Self.firstSeenStoreKey)
    }

    func recordFirstSeen(ieee: String, overwrite: Bool = false) {
        guard let id = activeBridgeID else { return }
        if !overwrite, firstSeenByBridge[id]?[ieee] != nil { return }
        let now = Date()
        firstSeenByBridge[id, default: [:]][ieee] = now
        deviceFirstSeen[ieee] = now
        persistFirstSeen()
    }

    func removeFirstSeen(ieee: String) {
        guard let id = activeBridgeID else { return }
        guard firstSeenByBridge[id]?.removeValue(forKey: ieee) != nil else { return }
        deviceFirstSeen.removeValue(forKey: ieee)
        persistFirstSeen()
    }
}
