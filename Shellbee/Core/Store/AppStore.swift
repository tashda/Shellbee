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
    /// Friendly bridge name (`ConnectionConfig.displayName`). Carried alongside
    /// `activeBridgeID` so per-bridge surfaces (Live Activities, notifications)
    /// can show user-readable attribution without a registry round-trip.
    private(set) var activeBridgeName: String = ""
    private static let firstSeenStoreKey = "AppStore.deviceFirstSeen"
    /// Legacy single-blob key (one big dict) — read once on first launch after
    /// the per-bridge migration and then dropped. Replaced by `firstSeenKey(for:)`
    /// which writes one record per bridge so two stores running concurrently
    /// can't race the read-modify-write loop.
    private static let firstSeenByBridgeStoreKey = "AppStore.deviceFirstSeenByBridge"
    private static func firstSeenKey(for bridgeID: UUID) -> String {
        "AppStore.deviceFirstSeen.\(bridgeID.uuidString)"
    }
    /// Legacy first-seen data loaded from the pre-multi-bridge format. Migrated
    /// into `firstSeenByBridge` under the first bridge id we see via
    /// `setActiveBridge(_:)` and then cleared.
    private var pendingLegacyFirstSeen: [String: Date]?
    var otaUpdates: [String: OTAUpdateStatus] = [:]
    var logEntries: [LogEntry] = []
    var rawLogEntries: [LogEntry] = []
    /// Id of the most recent log entry that flagged the bridge as needing
    /// a restart (a Z2M log line containing "restart required"). Captured
    /// when `bridgeInfo.restartRequired` flips false → true so the
    /// "Restart Required" notice in Settings can deep-link to the source
    /// log entry on long-press. Cleared when restart_required goes false.
    var restartTriggerLogID: UUID?
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
        // Multi-bridge: only clear THIS bridge's OTA activity; other bridges'
        // activities stay alive. activeBridgeID is preserved here — it's
        // cleared explicitly via `clearActiveBridge()` only on disconnect.
        OTAUpdateLiveActivityCoordinator.shared.clear(bridgeID: activeBridgeID)
    }

    // MARK: - Active bridge tracking

    /// Called by the session controller after a successful connection. Loads
    /// this bridge's first-seen slot into the published `deviceFirstSeen`
    /// mirror, and migrates any pending legacy data into this bridge's slot.
    func setActiveBridge(_ id: UUID, name: String = "") {
        // Lazy load this bridge's slot from disk if we don't have it yet.
        // Each store touches only its own slot, so two concurrent bridges
        // can each load and persist independently without racing.
        if firstSeenByBridge[id] == nil {
            firstSeenByBridge[id] = Self.loadFirstSeenSlot(for: id)
        }
        if let legacy = pendingLegacyFirstSeen, !legacy.isEmpty {
            // Merge legacy data under this bridge — first connect after upgrade
            // attributes everything to whichever bridge the user reached first.
            firstSeenByBridge[id, default: [:]].merge(legacy) { existing, _ in existing }
            pendingLegacyFirstSeen = nil
        }
        activeBridgeID = id
        activeBridgeName = name
        deviceFirstSeen = firstSeenByBridge[id] ?? [:]
        // Persist now (handles legacy migration too) — safe because
        // persistFirstSeen only writes activeBridgeID's slot.
        if pendingLegacyFirstSeen == nil && firstSeenByBridge[id]?.isEmpty == false {
            persistFirstSeen()
        }
    }

    /// Called on disconnect (not on simple reconnect). Clears the active
    /// pointer; the published mirror has already been cleared by `reset`.
    func clearActiveBridge() {
        activeBridgeID = nil
        activeBridgeName = ""
    }

    // MARK: - First-seen persistence

    private func loadFirstSeen() {
        // Migration path — try the old single-blob `byBridge` key. If found,
        // split it into per-bridge keys and clear the blob. Each per-bridge
        // store from this point on touches only its own UserDefaults key, so
        // concurrent connects can't race the persistence layer.
        if let data = UserDefaults.standard.data(forKey: Self.firstSeenByBridgeStoreKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            for (key, ieeeMap) in decoded {
                guard let id = UUID(uuidString: key) else { continue }
                firstSeenByBridge[id] = ieeeMap.mapValues { Date(timeIntervalSince1970: $0) }
                let asDouble = ieeeMap
                if let payload = try? JSONEncoder().encode(asDouble) {
                    UserDefaults.standard.set(payload, forKey: Self.firstSeenKey(for: id))
                }
            }
            UserDefaults.standard.removeObject(forKey: Self.firstSeenByBridgeStoreKey)
            return
        }

        // Walk every per-bridge key — UserDefaults doesn't expose a prefix query,
        // but `firstSeenByBridge` is initialised lazily per-bridge in
        // `setActiveBridge` (it reads its own slot from disk on demand).
        // For pre-existing data populated outside this run, do nothing here.

        // Final fall-back: legacy single-tenant format. Stash it for migration
        // into whichever bridge becomes active first.
        if let raw = UserDefaults.standard.dictionary(forKey: Self.firstSeenStoreKey) as? [String: Double] {
            pendingLegacyFirstSeen = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    /// Persist only the active bridge's slot — never touch other bridges'
    /// keys. Each per-bridge store is the sole writer for its own key, so
    /// concurrent multi-bridge writes never race.
    private func persistFirstSeen() {
        guard let id = activeBridgeID else { return }
        let slot = firstSeenByBridge[id] ?? [:]
        let encodable = slot.mapValues { $0.timeIntervalSince1970 }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        UserDefaults.standard.set(data, forKey: Self.firstSeenKey(for: id))
        // Drop the legacy single-tenant key once a per-bridge write exists.
        UserDefaults.standard.removeObject(forKey: Self.firstSeenStoreKey)
    }

    /// Read this bridge's slot from UserDefaults. Used by `setActiveBridge` so
    /// each per-bridge store loads its own slot on demand rather than holding
    /// a copy of every other bridge's data.
    private static func loadFirstSeenSlot(for id: UUID) -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: firstSeenKey(for: id)),
              let raw = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
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
