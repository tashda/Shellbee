import Foundation

@Observable
@MainActor
final class AppEnvironment {
    let discovery = Z2MDiscoveryService()
    let history = ConnectionHistory()
    let registry: BridgeRegistry
    let notificationPreferences = NotificationPreferences()
    /// Per-bridge OTA queues. Each bridge's bulk-OTA work runs independently —
    /// a 200-device check on bridge A doesn't serialize bridge B's update.
    private var otaQueues: [UUID: OTABulkOperationQueue] = [:]
    var selectedTab: AppTab = .home
    var pendingDeviceFilter: DeviceQuickFilter?
    var pendingLogSheet: LogSheetRequest?
    /// Phase 1 multi-bridge: a deep-link request to push a device detail.
    /// Carries the source bridge id so the route lands on the right store
    /// without a `setPrimary()` side effect at the call site.
    var pendingDeviceNavigation: DeviceRoute?
    private var hasStarted = false

    init() {
        let registry = BridgeRegistry(history: history)
        self.registry = registry
    }

    // MARK: - BridgeScope (the canonical bridge addressing API)

    /// Construct a `BridgeScope` for an explicit bridge id. The scope is
    /// lenient — if no session exists for the id (the user disconnected,
    /// or the id is stale), reads return empty data and writes are no-ops.
    /// UI that needs to react to disconnect observes `scope.isConnected`.
    ///
    /// Every multi-bridge-aware UI surface routes reads/writes through a
    /// `BridgeScope`. The legacy focused-bridge shims are gone — every
    /// action takes an explicit bridge id (or routes via `selectedScope`
    /// for the few top-level surfaces that have no other source of truth).
    func scope(for bridgeID: UUID) -> BridgeScope {
        BridgeScope(bridgeID: bridgeID, environment: self)
    }

    /// Scope for the currently-selected bridge in the picker UI, if any.
    /// Use this only at top-level UI surfaces that have no other source of
    /// truth for which bridge to address (e.g., the Home Permit Join
    /// toolbar in single-bridge mode). Detail views, lists, and per-row
    /// actions must always pass an explicit `bridgeID` instead.
    var selectedScope: BridgeScope? {
        guard let id = registry.primaryBridgeID else { return nil }
        return scope(for: id)
    }

    // MARK: - Merged multi-bridge accessors
    //
    // These return aggregated data across every connected bridge so the UI can
    // render "all devices everywhere" without per-screen plumbing. Each result
    // carries enough bridge metadata for the renderer to attribute rows back
    // to their source.

    /// Every device across every connected bridge, tagged with its source.
    /// Useful for the Devices tab in merged mode.
    var allDevices: [BridgeBoundDevice] {
        registry.orderedSessions.flatMap { session in
            session.store.devices.map { device in
                BridgeBoundDevice(bridgeID: session.bridgeID, bridgeName: session.displayName, device: device)
            }
        }
    }

    /// Every group across every connected bridge.
    var allGroups: [BridgeBoundGroup] {
        registry.orderedSessions.flatMap { session in
            session.store.groups.map { group in
                BridgeBoundGroup(bridgeID: session.bridgeID, bridgeName: session.displayName, group: group)
            }
        }
    }

    /// Every log entry across every connected bridge, sorted newest first.
    var allLogEntries: [BridgeBoundLogEntry] {
        registry.orderedSessions
            .flatMap { session in
                session.store.logEntries.map {
                    BridgeBoundLogEntry(bridgeID: session.bridgeID, bridgeName: session.displayName, entry: $0)
                }
            }
            .sorted { $0.entry.timestamp > $1.entry.timestamp }
    }

    /// All pending in-app notifications across every bridge. Tagged so the
    /// overlay can show bridge attribution on the banner and route dismissal
    /// back to the originating bridge's store.
    var allPendingNotifications: [BridgeBoundNotification] {
        registry.orderedSessions.flatMap { session in
            session.store.pendingNotifications.map {
                BridgeBoundNotification(bridgeID: session.bridgeID, bridgeName: session.displayName, notification: $0)
            }
        }
    }

    /// Total count of pending notifications across every bridge — drives the
    /// overlay's haptic + auto-dismiss scheduling without forcing the overlay
    /// to flatten the merged list every render.
    var totalPendingNotifications: Int {
        registry.orderedSessions.reduce(0) { $0 + $1.store.pendingNotifications.count }
    }

    /// Combined arrival-id snapshot across every connected bridge. SwiftUI
    /// observes the value to fire the overlay's "new notification" haptic
    /// across every bridge — the array changes whenever any bridge enqueues
    /// a new notification (each store rotates its own UUID on enqueue).
    var aggregateNotificationArrivalID: [UUID] {
        registry.orderedSessions.map(\.store.notificationArrivalID)
    }

    /// Total fast-track count across every bridge. The overlay schedules
    /// the next fast-track banner whenever this rises.
    var totalFastTrackNotifications: Int {
        registry.orderedSessions.reduce(0) { $0 + $1.store.fastTrackNotifications.count }
    }

    /// Pop the latest non-fast-track notification from whichever bridge holds
    /// the most recent one. Used when the overlay dismisses a banner.
    func popLatestPendingNotification() {
        // The overlay shows newest-first across bridges. Find the bridge with
        // the most-recently-enqueued notification and pop from there.
        var latestBridge: BridgeSession?
        var latestCount = 0
        for session in registry.orderedSessions {
            let count = session.store.pendingNotifications.count
            if count > latestCount {
                latestBridge = session
                latestCount = count
            }
        }
        if let store = latestBridge?.store, !store.pendingNotifications.isEmpty {
            store.pendingNotifications.removeLast()
        }
    }

    /// Clear every bridge's pending notifications. Used when the user
    /// dismisses the entire stack.
    func clearAllPendingNotifications() {
        for session in registry.orderedSessions {
            session.store.pendingNotifications.removeAll()
        }
    }

    /// Pop the next fast-track notification from whichever bridge has one.
    /// Fast-track is "show this once briefly" (e.g., "Copied").
    func popNextFastTrackNotification() -> BridgeBoundNotification? {
        for session in registry.orderedSessions {
            if let next = session.store.popFastTrackNotification() {
                return BridgeBoundNotification(
                    bridgeID: session.bridgeID,
                    bridgeName: session.displayName,
                    notification: next
                )
            }
        }
        return nil
    }

    /// True if any bridge has fast-track notifications waiting. Used by the
    /// overlay to drive its scheduler.
    var hasFastTrackNotifications: Bool {
        registry.orderedSessions.contains { !$0.store.fastTrackNotifications.isEmpty }
    }

    // MARK: - Connection state queries

    /// True if any connected (or previously-connected) session has reached
    /// `.connected` at least once. Used to decide whether to show the
    /// onboarding flow vs. the main interface on launch.
    var hasAnyBridgeBeenConnected: Bool {
        registry.orderedSessions.contains { $0.controller.hasBeenConnected }
    }

    /// True if the user has at least one saved bridge in `ConnectionHistory`.
    /// Used by RootView to decide whether to show the onboarding cover after
    /// the splash. Doesn't require a live session — covers the case where
    /// every bridge dropped before launch finished.
    var hasSavedBridges: Bool {
        !history.connections.isEmpty
    }

    static var maxReconnectAttempts: Int { ConnectionSessionController.configuredMaxReconnectAttempts }

    // MARK: - OTA bulk queues (per-bridge)

    /// Per-bridge OTA bulk queue. Lazily created on first access. Returns
    /// `nil` if the bridge isn't currently connected.
    func otaBulkQueue(for bridgeID: UUID) -> OTABulkOperationQueue? {
        guard let session = registry.session(for: bridgeID) else { return nil }
        return makeOrFetchQueue(for: session.store, bridgeID: bridgeID)
    }

    // MARK: - Connection lifecycle

    /// Connect to a bridge. Existing sessions stay live — connecting a new
    /// bridge never tears down others. The first session connected becomes
    /// the focused (primary) bridge automatically.
    func connect(config: ConnectionConfig) {
        selectedTab = .home
        let isFirst = registry.primary == nil
        registry.connect(config: config)
        if let session = registry.session(for: config.id) {
            wireNotificationFilter(into: session.store, bridgeID: session.bridgeID)
            ensureQueueWired(for: session)
        }
        if isFirst, let primary = registry.primary {
            registry.setPrimary(primary.bridgeID)
        }
    }

    /// Disconnect a single bridge. Other bridges remain connected.
    func disconnect(bridgeID: UUID) async {
        otaQueues.removeValue(forKey: bridgeID)
        await registry.disconnect(bridgeID: bridgeID)
    }

    /// Disconnect every bridge — used by "forget" / sign-out flows.
    func disconnectAll() async {
        otaQueues.removeAll()
        await registry.disconnectAll()
    }

    /// Cancel an in-flight connection attempt for a specific bridge.
    func cancelConnection(bridgeID: UUID) async {
        await registry.session(for: bridgeID)?.controller.cancelConnection()
    }

    /// Forget a specific bridge's saved configuration.
    func forgetServer(bridgeID: UUID) async {
        await registry.session(for: bridgeID)?.controller.forgetServer()
    }

    /// Retry a specific bridge after its connection was lost.
    func retryFromLost(bridgeID: UUID) {
        registry.session(for: bridgeID)?.controller.retryFromLost()
    }

    /// Clear a specific bridge's error message.
    func clearErrorMessage(bridgeID: UUID) {
        registry.session(for: bridgeID)?.controller.clearErrorMessage()
    }

    /// Restart a specific bridge's Z2M instance. Optimistically clears
    /// runtime stats (health, online flag) so home/settings surfaces don't
    /// keep showing pre-restart uptime/message counts as if they were
    /// current — Z2M won't republish those until reconnect, which can take
    /// several seconds and makes the user doubt the restart actually fired.
    func restartBridge(_ bridgeID: UUID) {
        if let store = registry.session(for: bridgeID)?.store {
            store.bridgeHealth = nil
            store.bridgeOnline = false
        }
        send(bridge: bridgeID, topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    /// Refresh devices + groups for a specific bridge.
    func refreshBridgeData(bridgeID: UUID) async {
        send(bridge: bridgeID, topic: Z2MTopics.Request.devices, payload: .string(""))
        send(bridge: bridgeID, topic: Z2MTopics.Request.groups, payload: .string(""))
        try? await Task.sleep(for: .milliseconds(600))
    }

    // MARK: - Per-bridge sends

    /// Send a request explicitly to a specific bridge. The canonical write
    /// path — every UI mutation routes through here. UI surfaces typically
    /// hold a `BridgeScope` and call `scope.send(...)` rather than
    /// reaching for this directly.
    func send(bridge bridgeID: UUID, topic: String, payload: JSONValue) {
        registry.session(for: bridgeID)?.controller.send(topic: topic, payload: payload)
    }

    /// Multi-bridge variant of `sendBridgeOptions` — addresses a specific
    /// bridge by id rather than the focused one. Used by per-bridge Settings
    /// pages when more than one bridge is connected.
    func sendBridgeOptions(_ options: [String: JSONValue], to bridgeID: UUID) {
        send(bridge: bridgeID, topic: Z2MTopics.Request.options, payload: .object(["options": .object(options)]))
    }

    // MARK: - Tab-level navigation helpers

    func showDevices(filter: DeviceQuickFilter) {
        pendingDeviceFilter = filter
        selectedTab = .devices
    }

    // MARK: - Lifecycle

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        ConnectionLiveActivityCoordinator.shared.clearAll()
        OTAUpdateLiveActivityCoordinator.shared.clearAll()
        await Task.yield()

        let env = ProcessInfo.processInfo.environment
        if env["UI_TEST_MODE"] == "1" {
            if env["UI_TEST_CLEAR_SAVED_SERVER"] == "1" {
                ConnectionConfig.clear()
                return
            }
            if let host = env["UI_TEST_Z2M_HOST"],
               let portStr = env["UI_TEST_Z2M_PORT"],
               let port = Int(portStr) {
                let token = env["UI_TEST_Z2M_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
                connect(config: ConnectionConfig(host: host, port: port, useTLS: false, basePath: "/", authToken: token))
                return
            }
        }

        // Migrate pre-existing installs (single saved bridge, no auto-connect
        // flag) so the user lands on their bridge after upgrading instead of
        // an empty UI.
        history.performFirstLaunchMigrationIfNeeded()

        // Auto-connect to every saved bridge that the user has explicitly
        // marked for auto-connect — and only those. No "last successful" or
        // default-bridge fallback: if the user disables auto-connect on every
        // bridge, the app starts cleanly with no live session.
        let toConnect = history.connections.filter { history.isAutoConnect($0) }
        for config in toConnect {
            connect(config: config)
        }
    }

    /// Set up notification filtering on a freshly-created store so notifications
    /// from that bridge are routed through the user's global preferences. The
    /// per-bridge mute toggle short-circuits all category filtering — muted
    /// bridges produce zero notifications regardless of category settings.
    private func wireNotificationFilter(into store: AppStore, bridgeID: UUID) {
        let prefs = notificationPreferences
        store.notificationFilter = { [weak store] notification in
            if prefs.isMuted(bridgeID: bridgeID) { return false }
            guard let category = notification.category else { return true }
            let bridgeLevel = store?.bridgeInfo?.logLevel
            return prefs.isEnabled(category, bridgeLogLevel: bridgeLevel)
        }
    }

    private func ensureQueueWired(for session: BridgeSession) {
        _ = makeOrFetchQueue(for: session.store, bridgeID: session.bridgeID)
    }

    private func makeOrFetchQueue(for store: AppStore, bridgeID: UUID) -> OTABulkOperationQueue {
        if let existing = otaQueues[bridgeID] { return existing }
        let queue = OTABulkOperationQueue(
            sender: { [weak self, bridgeID] topic, payload in
                self?.send(bridge: bridgeID, topic: topic, payload: payload)
            },
            onCompletion: { [weak store] summary in
                store?.enqueueOTABulkSummary(summary)
            }
        )
        store.otaResponseForwarding = { [weak queue] name, success, kind in
            queue?.handleResponse(friendlyName: name, success: success, kind: kind)
        }
        otaQueues[bridgeID] = queue
        return queue
    }
}
