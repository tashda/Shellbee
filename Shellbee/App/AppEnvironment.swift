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
    /// Fallback empty store returned by `store` while no bridge is connected.
    /// Keeps every read-site that touches `environment.store.devices` etc.
    /// crash-free during the brief window between launch and first connect.
    private let fallbackStore = AppStore()
    var selectedTab: AppTab = .home
    var pendingDeviceFilter: DeviceQuickFilter?
    var pendingLogSheet: LogSheetRequest?
    var pendingDeviceNavigation: String?
    private var hasStarted = false

    init() {
        let registry = BridgeRegistry(history: history)
        self.registry = registry
        wireNotificationFilter(into: fallbackStore)
    }

    /// Construct a `BridgeScope` for an explicit bridge id. Returns `nil`
    /// if no session exists for that id (the user disconnected, or the id
    /// is stale). All new multi-bridge-aware UI should route reads/writes
    /// through a `BridgeScope` rather than the deprecated `store` /
    /// `send(topic:)` shims below.
    func scope(for bridgeID: UUID) -> BridgeScope? {
        guard let session = registry.session(for: bridgeID) else { return nil }
        return BridgeScope(bridgeID: bridgeID, session: session, environment: self)
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

    /// The focused bridge's store. Falls back to an empty store while no
    /// bridge is connected so the UI can read it safely on cold start.
    @available(*, deprecated, message: "Use scope(for:).store. The focused-bridge shim is being removed; pass an explicit bridgeID through the view hierarchy instead.")
    var store: AppStore {
        registry.primary?.store ?? fallbackStore
    }

    /// The focused bridge's session controller, if any.
    @available(*, deprecated, message: "Use scope(for:).session.controller or registry.session(for:) — explicit bridge addressing only.")
    var session: ConnectionSessionController? {
        registry.primary?.controller
    }

    // MARK: - Merged multi-bridge accessors
    //
    // These return aggregated data across every connected bridge so the UI can
    // render "all devices everywhere" without per-screen plumbing. Each result
    // carries enough bridge metadata for the renderer to attribute rows back
    // to their source. UI code that wants merged display reads these; UI that
    // remains scoped to the focused bridge keeps using `.store.devices` etc.

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

    /// Look up which bridge owns a device with the given friendly name. Returns
    /// the first match — friendly names are unique within a single Z2M
    /// instance but can collide across bridges (a real concern for users with
    /// multiple identical device fleets).
    func bridge(forDevice friendlyName: String) -> BridgeSession? {
        registry.orderedSessions.first { session in
            session.store.devices.contains { $0.friendlyName == friendlyName }
        }
    }

    /// Look up which bridge owns a group with the given id. Group ids are
    /// scoped to a single Z2M instance, so the same numeric id can exist on
    /// multiple bridges — first-match resolution returns the focused bridge's
    /// owner first when both contain it.
    func bridge(forGroup groupID: Int) -> BridgeSession? {
        // Prefer the focused bridge's match if any, then fall back to others
        // — keeps multi-bridge group navigation aligned with the user's
        // current focus when both bridges have a group with the same id.
        if let primary = registry.primary,
           primary.store.groups.contains(where: { $0.id == groupID }) {
            return primary
        }
        return registry.orderedSessions.first { session in
            session.store.groups.contains { $0.id == groupID }
        }
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

    @available(*, deprecated, message: "Use scope(for:).connectionState. Reads the focused bridge silently — being removed.")
    var connectionState: ConnectionSessionController.State {
        registry.primary?.controller.connectionState ?? .idle
    }

    @available(*, deprecated, message: "Use scope(for:).session.config or registry.session(for:)?.config — explicit bridge addressing only.")
    var connectionConfig: ConnectionConfig? {
        registry.primary?.controller.connectionConfig
    }

    @available(*, deprecated, message: "Use registry.session(for:)?.controller.hasBeenConnected — explicit bridge addressing only.")
    var hasBeenConnected: Bool {
        registry.primary?.controller.hasBeenConnected ?? false
    }

    @available(*, deprecated, message: "Use registry.session(for:)?.controller.errorMessage — explicit bridge addressing only.")
    var errorMessage: String? {
        registry.primary?.controller.errorMessage
    }

    /// The OTA bulk queue for the focused bridge. Lazily created on first
    /// access per bridge so that newly-connected bridges get their own queue.
    @available(*, deprecated, message: "Use otaBulkQueue(for:) with an explicit bridge id.")
    var otaBulkQueue: OTABulkOperationQueue {
        guard let primary = registry.primary else {
            return makeOrFetchQueue(for: fallbackStore, bridgeID: nil)
        }
        return makeOrFetchQueue(for: primary.store, bridgeID: primary.bridgeID)
    }

    /// Per-bridge OTA bulk queue. Lazily created on first access. Returns
    /// `nil` if the bridge isn't currently connected.
    func otaBulkQueue(for bridgeID: UUID) -> OTABulkOperationQueue? {
        guard let session = registry.session(for: bridgeID) else { return nil }
        return makeOrFetchQueue(for: session.store, bridgeID: bridgeID)
    }

    static var maxReconnectAttempts: Int { ConnectionSessionController.configuredMaxReconnectAttempts }

    /// Connect to a bridge. Existing sessions stay live — connecting a new
    /// bridge never tears down others. The first session connected becomes
    /// the focused (primary) bridge automatically.
    func connect(config: ConnectionConfig) {
        selectedTab = .home
        let isFirst = registry.primary == nil
        registry.connect(config: config)
        if let session = registry.session(for: config.id) {
            wireNotificationFilter(into: session.store)
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

    /// Legacy: disconnects the focused bridge only (back-compat for callers
    /// that haven't been ported to multi-bridge yet).
    @available(*, deprecated, message: "Use disconnect(bridgeID:) with an explicit bridge id.")
    func disconnect() async {
        guard let id = registry.primaryBridgeID else { return }
        await disconnect(bridgeID: id)
    }

    @available(*, deprecated, message: "Use cancelConnection(bridgeID:) with an explicit bridge id.")
    func cancelConnection() async {
        await registry.primary?.controller.cancelConnection()
    }

    /// Cancel an in-flight connection attempt for a specific bridge.
    func cancelConnection(bridgeID: UUID) async {
        await registry.session(for: bridgeID)?.controller.cancelConnection()
    }

    @available(*, deprecated, message: "Use forgetServer(bridgeID:) with an explicit bridge id.")
    func forgetServer() async {
        await registry.primary?.controller.forgetServer()
    }

    /// Forget a specific bridge's saved configuration.
    func forgetServer(bridgeID: UUID) async {
        await registry.session(for: bridgeID)?.controller.forgetServer()
    }

    @available(*, deprecated, message: "Use retryFromLost(bridgeID:) with an explicit bridge id.")
    func retryFromLost() {
        registry.primary?.controller.retryFromLost()
    }

    /// Retry a specific bridge after its connection was lost.
    func retryFromLost(bridgeID: UUID) {
        registry.session(for: bridgeID)?.controller.retryFromLost()
    }

    @available(*, deprecated, message: "Use clearErrorMessage(bridgeID:) with an explicit bridge id.")
    func clearErrorMessage() {
        registry.primary?.controller.clearErrorMessage()
    }

    /// Clear a specific bridge's error message.
    func clearErrorMessage(bridgeID: UUID) {
        registry.session(for: bridgeID)?.controller.clearErrorMessage()
    }

    @available(*, deprecated, message: "Use restartBridge(_:) with an explicit bridge id, or scope.restart().")
    func restartBridge() {
        guard let id = registry.primaryBridgeID else { return }
        send(bridge: id, topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    /// Restart a specific bridge — the multi-bridge variant of `restartBridge()`.
    func restartBridge(_ bridgeID: UUID) {
        send(bridge: bridgeID, topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    @available(*, deprecated, message: "Use refreshBridgeData(bridgeID:) with an explicit bridge id, or refresh every connected bridge.")
    func refreshBridgeData() async {
        guard let id = registry.primaryBridgeID else { return }
        await refreshBridgeData(bridgeID: id)
    }

    /// Refresh devices + groups for a specific bridge.
    func refreshBridgeData(bridgeID: UUID) async {
        send(bridge: bridgeID, topic: Z2MTopics.Request.devices, payload: .string(""))
        send(bridge: bridgeID, topic: Z2MTopics.Request.groups, payload: .string(""))
        try? await Task.sleep(for: .milliseconds(600))
    }

    /// Send a request to the focused bridge. Per-bridge routing comes via
    /// `send(bridge:topic:payload:)`.
    @available(*, deprecated, message: "Use send(bridge:topic:payload:) with an explicit bridge id, or scope.send(topic:payload:).")
    func send(topic: String, payload: JSONValue) {
        registry.primary?.controller.send(topic: topic, payload: payload)
    }

    /// Send a request explicitly to a specific bridge. Used by per-bridge
    /// settings screens, the OTA queue, and any UI that needs to address
    /// something other than the focused bridge.
    func send(bridge bridgeID: UUID, topic: String, payload: JSONValue) {
        registry.session(for: bridgeID)?.controller.send(topic: topic, payload: payload)
    }

    /// Sends a `bridge/request/options` request with the payload wrapped in
    /// the `{"options": {...}}` envelope that z2m requires.
    @available(*, deprecated, message: "Use sendBridgeOptions(_:to:) with an explicit bridge id, or scope.sendOptions(_:).")
    func sendBridgeOptions(_ options: [String: JSONValue]) {
        guard let id = registry.primaryBridgeID else { return }
        sendBridgeOptions(options, to: id)
    }

    /// Multi-bridge variant of `sendBridgeOptions(_:)` — addresses a specific
    /// bridge by id rather than the focused one. Used by per-bridge Settings
    /// pages when more than one bridge is connected.
    func sendBridgeOptions(_ options: [String: JSONValue], to bridgeID: UUID) {
        send(bridge: bridgeID, topic: Z2MTopics.Request.options, payload: .object(["options": .object(options)]))
    }

    @available(*, deprecated, message: "Use scope(for:).sendDeviceState(_:payload:) — explicit bridge addressing only.")
    func sendDeviceState(_ friendlyName: String, payload: JSONValue) {
        guard let id = registry.primaryBridgeID else { return }
        send(bridge: id, topic: Z2MTopics.deviceSet(friendlyName), payload: payload)
    }

    /// Asks the device to physically identify itself (blink/beep) via the
    /// Zigbee Identify cluster.
    @available(*, deprecated, message: "Use scope(for:).identifyDevice(_:) — explicit bridge addressing only.")
    func identifyDevice(_ friendlyName: String) {
        guard let scope = selectedScope else { return }
        scope.identifyDevice(friendlyName)
    }

    @available(*, deprecated, message: "Use scope(for:).renameDevice(from:to:homeassistantRename:) — explicit bridge addressing only.")
    func renameDevice(from: String, to: String, homeassistantRename: Bool) {
        guard let scope = selectedScope else { return }
        scope.renameDevice(from: from, to: to, homeassistantRename: homeassistantRename)
    }

    func showDevices(filter: DeviceQuickFilter) {
        pendingDeviceFilter = filter
        selectedTab = .devices
    }

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

        // Auto-connect to every saved bridge that the user has explicitly
        // marked for auto-connect. Falls back to the default bridge, then to
        // the legacy last-successful config.
        let toConnect = autoConnectTargets()
        for config in toConnect {
            connect(config: config)
        }
    }

    private func autoConnectTargets() -> [ConnectionConfig] {
        let auto = history.connections.filter { history.isAutoConnect($0) }
        if !auto.isEmpty { return auto }
        if let preferred = history.defaultBridge { return [preferred] }
        if let last = ConnectionConfig.load() { return [last] }
        return []
    }

    /// Set up notification filtering on a freshly-created store so notifications
    /// from that bridge are routed through the user's global preferences.
    private func wireNotificationFilter(into store: AppStore) {
        let prefs = notificationPreferences
        store.notificationFilter = { [weak store] notification in
            guard let category = notification.category else { return true }
            let bridgeLevel = store?.bridgeInfo?.logLevel
            return prefs.isEnabled(category, bridgeLogLevel: bridgeLevel)
        }
    }

    private func ensureQueueWired(for session: BridgeSession) {
        _ = makeOrFetchQueue(for: session.store, bridgeID: session.bridgeID)
    }

    private func makeOrFetchQueue(for store: AppStore, bridgeID: UUID?) -> OTABulkOperationQueue {
        if let bridgeID, let existing = otaQueues[bridgeID] {
            return existing
        }
        let queue = OTABulkOperationQueue(
            sender: { [weak self, bridgeID] topic, payload in
                guard let self else { return }
                if let bridgeID {
                    self.send(bridge: bridgeID, topic: topic, payload: payload)
                } else {
                    self.send(topic: topic, payload: payload)
                }
            },
            onCompletion: { [weak store] summary in
                store?.enqueueOTABulkSummary(summary)
            }
        )
        store.otaResponseForwarding = { [weak queue] name, success, kind in
            queue?.handleResponse(friendlyName: name, success: success, kind: kind)
        }
        if let bridgeID {
            otaQueues[bridgeID] = queue
        }
        return queue
    }
}
