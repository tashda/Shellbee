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

    /// The focused bridge's store. Falls back to an empty store while no
    /// bridge is connected so the UI can read it safely on cold start.
    var store: AppStore {
        registry.primary?.store ?? fallbackStore
    }

    /// The focused bridge's session controller, if any.
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

    var connectionState: ConnectionSessionController.State {
        session?.connectionState ?? .idle
    }

    var connectionConfig: ConnectionConfig? {
        session?.connectionConfig
    }

    var hasBeenConnected: Bool {
        session?.hasBeenConnected ?? false
    }

    var errorMessage: String? {
        session?.errorMessage
    }

    /// The OTA bulk queue for the focused bridge. Lazily created on first
    /// access per bridge so that newly-connected bridges get their own queue.
    var otaBulkQueue: OTABulkOperationQueue {
        guard let primary = registry.primary else {
            return makeOrFetchQueue(for: fallbackStore, bridgeID: nil)
        }
        return makeOrFetchQueue(for: primary.store, bridgeID: primary.bridgeID)
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
    func disconnect() async {
        guard let id = registry.primaryBridgeID else { return }
        await disconnect(bridgeID: id)
    }

    func cancelConnection() async {
        await session?.cancelConnection()
    }

    func forgetServer() async {
        await session?.forgetServer()
    }

    func retryFromLost() {
        session?.retryFromLost()
    }

    func clearErrorMessage() {
        session?.clearErrorMessage()
    }

    func restartBridge() {
        send(topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    func refreshBridgeData() async {
        send(topic: Z2MTopics.Request.devices, payload: .string(""))
        send(topic: Z2MTopics.Request.groups, payload: .string(""))
        try? await Task.sleep(for: .milliseconds(600))
    }

    /// Send a request to the focused bridge. Per-bridge routing comes via
    /// `send(bridge:topic:payload:)`.
    func send(topic: String, payload: JSONValue) {
        session?.send(topic: topic, payload: payload)
    }

    /// Send a request explicitly to a specific bridge. Used by per-bridge
    /// settings screens, the OTA queue, and any UI that needs to address
    /// something other than the focused bridge.
    func send(bridge bridgeID: UUID, topic: String, payload: JSONValue) {
        registry.session(for: bridgeID)?.controller.send(topic: topic, payload: payload)
    }

    /// Sends a `bridge/request/options` request with the payload wrapped in
    /// the `{"options": {...}}` envelope that z2m requires.
    func sendBridgeOptions(_ options: [String: JSONValue]) {
        send(topic: Z2MTopics.Request.options, payload: .object(["options": .object(options)]))
    }

    func sendDeviceState(_ friendlyName: String, payload: JSONValue) {
        send(topic: Z2MTopics.deviceSet(friendlyName), payload: payload)
    }

    /// Asks the device to physically identify itself (blink/beep) via the
    /// Zigbee Identify cluster.
    func identifyDevice(_ friendlyName: String) {
        let store = self.store
        guard !store.identifyInProgress.contains(friendlyName) else { return }
        store.identifyInProgress.insert(friendlyName)
        sendDeviceState(friendlyName, payload: .object(["identify": .string("identify")]))

        Task { [weak store] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                _ = store?.identifyInProgress.remove(friendlyName)
            }
        }
    }

    func renameDevice(from: String, to: String, homeassistantRename: Bool) {
        let trimmed = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != from else { return }
        store.optimisticRename(from: from, to: trimmed)
        send(topic: Z2MTopics.Request.deviceRename, payload: .object([
            "from": .string(from),
            "to": .string(trimmed),
            "homeassistant_rename": .bool(homeassistantRename)
        ]))
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
