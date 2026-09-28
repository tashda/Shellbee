import Foundation

@Observable
final class ConnectionSessionController {
    enum State: Equatable, Sendable {
        case idle
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(String)
        case lost(String)

        var isConnected: Bool { self == .connected }
    }

    var connectionState: State = .idle
    var connectionConfig: ConnectionConfig? = ConnectionConfig.load()
    var errorMessage: String?
    private(set) var hasBeenConnected = false
    /// When the last batch of messages arrived. The splash waits for the
    /// connect burst to go quiet before showing the app.
    @ObservationIgnored private(set) var lastInboundAt: Date?

    /// Set when `connect(config:)` is invoked. Lets us defer `store.reset()`
    /// until the new handshake succeeds — a failed switch keeps the prior
    /// bridge's data on screen instead of stranding the user on an empty UI.
    /// Also forces `.failed` semantics on a failed switch from a working
    /// connection, so it doesn't masquerade as a network blip (.lost).
    private var pendingFreshConnect: Bool = false
    private var priorConfigForRestore: ConnectionConfig?
    private var priorHadConnectedForRestore: Bool = false

    /// Receives every inbound (topic, payload) before routing. Used by the
    /// MQTT inspector in Developer Mode. Set on view appear, clear on disappear.
    var rawInboundTap: ((String, JSONValue) -> Void)?

    private let store: AppStore
    private let history: ConnectionHistory
    private let client = Z2MWebSocketClient()
    private let router = Z2MMessageRouter()
    private let pathMonitor = NetworkPathMonitor()
    /// Identifies which saved bridge this controller represents. Tagged onto
    /// every `Z2MEvent` before it's applied to the store (Phase 2 multi-bridge),
    /// and used as the dedup key for Live Activities so multiple bridges don't
    /// collide on a single activity slot.
    let bridgeID: UUID

    private var sessionTask: Task<Void, Never>?
    private var pathObserverTask: Task<Void, Never>?

    // User-configurable preference keys read via UserDefaults. Defaults: 3
    // reconnect attempts, both live activities on.
    static let maxReconnectAttemptsKey = "connectionMaxReconnectAttempts"
    static let permitJoinLiveActivityEnabledKey = "permitJoinLiveActivityEnabled"
    static let touchlinkLiveActivityEnabledKey = "touchlinkLiveActivityEnabled"
    static let otaLiveActivityEnabledKey = "otaLiveActivityEnabled"
    static let otaScheduledLiveActivityEnabledKey = "otaScheduledLiveActivityEnabled"
    static let defaultMaxReconnectAttempts: Int = 3
    static let maxReconnectAttemptsRange: ClosedRange<Int> = 1...20
    private static let baseReconnectDelay: Double = 1
    private static let maxReconnectDelay: Double = 30
    /// The longest a pull to refresh keeps its spinner up.
    private static let refreshTimeout: TimeInterval = 10

    static var configuredMaxReconnectAttempts: Int {
        let stored = UserDefaults.standard.integer(forKey: maxReconnectAttemptsKey)
        return stored > 0 ? stored : defaultMaxReconnectAttempts
    }


    init(store: AppStore, history: ConnectionHistory, bridgeID: UUID = UUID()) {
        self.store = store
        self.history = history
        self.bridgeID = bridgeID
        startPathObserver()
    }

    private func startPathObserver() {
        pathMonitor.start()
        pathObserverTask?.cancel()
        pathObserverTask = Task { [weak self] in
            guard let self else { return }
            for await status in self.pathMonitor.updates() {
                if Task.isCancelled { return }
                await self.handlePathChange(status)
            }
        }
    }

    private func handlePathChange(_ status: NetworkPathMonitor.Status) async {
        switch status {
        case .unsatisfied:
            // Drop the socket immediately so we surface "lost" within a second
            // instead of waiting for the 10s socket read timeout. The session
            // task observes the disconnection and enters reconnect/backoff.
            switch connectionState {
            case .connected, .connecting, .reconnecting:
                let wasActive = connectionState.isConnected
                store.isConnected = false
                connectionState = hasBeenConnected
                    ? .lost("Network unavailable")
                    : .failed("Network unavailable")
                await client.disconnect()
                if hasBeenConnected && wasActive {
                    postConnectionLostNotification(reason: "Network unavailable")
                }
            case .idle, .lost, .failed:
                break
            }
        case .satisfied:
            // Network came back. If we were waiting in a lost state with a
            // saved config and a previously established session, kick a retry
            // immediately rather than waiting for the next foreground.
            guard hasBeenConnected, connectionConfig != nil else { return }
            switch connectionState {
            case .lost, .failed, .idle:
                retryFromLost()
            case .connecting, .connected, .reconnecting:
                break
            }
        case .unknown:
            break
        }
    }

    func connect(config: ConnectionConfig) {
        // A user-initiated connect is a fresh attempt. Capture the prior config
        // and connection state so we can restore them if the new attempt fails —
        // keeping the user on their working bridge rather than stranding them
        // on an empty UI. The actual store.reset() runs only after the new
        // handshake succeeds (see establishConnection).
        pendingFreshConnect = true
        priorConfigForRestore = connectionConfig
        priorHadConnectedForRestore = hasBeenConnected

        hasBeenConnected = false
        store.isConnected = false
        connectionConfig = config
        errorMessage = nil
        // Set before the session task runs, so anything checking right
        // after (the launch splash, a second scene) sees the attempt.
        connectionState = .connecting
        startSession(config: config)
    }

    func retryFromLost() {
        guard let config = connectionConfig else { return }
        switch connectionState {
        case .lost, .failed, .idle:
            connectionState = .connecting
        case .connecting, .connected, .reconnecting:
            return
        }
        errorMessage = nil
        startSession(config: config)
    }

    /// Pull to refresh. Zigbee2MQTT has no request for its device list or
    /// states, but sends everything again on a new connection, so this
    /// reconnects without clearing the store: what's on screen stays and
    /// updates in place. Returns once the fresh data has landed and gone
    /// quiet, so the refresh spinner covers the whole reload.
    func refresh() async {
        guard let config = connectionConfig, connectionState == .connected,
              !store.networkMapIsRefreshing else { return }
        store.hasReceivedDevices = false
        store.hasReceivedGroups = false
        startSession(config: config)

        let started = Date()
        while Date().timeIntervalSince(started) < Self.refreshTimeout {
            try? await Task.sleep(for: .milliseconds(100))
            switch connectionState {
            case .connected:
                if store.hasReceivedDevices, let last = lastInboundAt,
                   Date().timeIntervalSince(last) >= LaunchReadiness.quietPeriod { return }
            case .failed, .lost, .idle:
                return
            case .connecting, .reconnecting:
                continue
            }
        }
    }

    func cancelConnection() async {
        let teardownTask = prepareForDisconnect()
        await teardownTask.value
    }

    func disconnect() async {
        let teardownTask = prepareForDisconnect()
        hasBeenConnected = false
        errorMessage = nil
        store.reset()
        store.clearActiveBridge()
        await teardownTask.value
    }

    func forgetServer() async {
        await disconnect()
        ConnectionConfig.clear()
        connectionConfig = nil
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    func send(topic: String, payload: JSONValue) {
        let envelope = Z2MOutboundEnvelope(topic: topic, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        Task {
            try? await client.send(data)
        }
    }

    /// Like `send`, but awaits actual transmission and reports whether the
    /// request left the device. `send` is fire-and-forget and swallows a
    /// `notConnected` failure (e.g. mid-reconnect) silently, which is fine
    /// for one-off UI actions but hides a lost request from callers that
    /// need to know — such as the bulk OTA queue, which would otherwise
    /// wait out its full per-device timeout for a response that can never
    /// arrive (see #144).
    func sendAwaitingTransmission(topic: String, payload: JSONValue) async -> Bool {
        let envelope = Z2MOutboundEnvelope(topic: topic, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return false }
        do {
            try await client.send(data)
            return true
        } catch {
            return false
        }
    }

    private func prepareForDisconnect() -> Task<Void, Never> {
        sessionTask?.cancel()
        sessionTask = nil
        store.isConnected = false
        connectionState = .idle
        return Task { [client] in
            await client.disconnect()
        }
    }

    private func startSession(config: ConnectionConfig) {
        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            await self?.runSession(config: config)
        }
    }

    private func runSession(config: ConnectionConfig) async {
        await client.disconnect()
        store.isConnected = false
        connectionState = .connecting

        do {
            let events = try await establishConnection(config: config)
            await monitorConnection(config: config, events: events)
        } catch is CancellationError {
            return
        } catch {
            await handleFailure(Z2MError.interpret(error))
        }
    }

    private func establishConnection(config: ConnectionConfig) async throws -> AsyncStream<Z2MSocketEvent> {
        guard let url = config.webSocketURL else {
            throw Z2MError.invalidURL
        }

        let events = try await client.connect(url: url, allowInvalidCertificates: config.allowInvalidCertificates)

        // Handshake succeeded — now it's safe to clear the prior bridge's state.
        // Doing this earlier strands the user on an empty UI when the switch
        // fails (see #68).
        if pendingFreshConnect {
            store.reset()
            pendingFreshConnect = false
            priorConfigForRestore = nil
            priorHadConnectedForRestore = false
        }

        config.save()
        connectionState = .connected
        hasBeenConnected = true
        store.isConnected = true
        store.setActiveBridge(config.id, name: config.displayName)
        history.add(config)
        SentryService.shared.recordBridgeEvent("connected", bridgeName: config.displayName)
        requestInitialState()
        return events
    }

    private func requestInitialState() {
        // bridge/info, bridge/devices and bridge/groups aren't requested:
        // Zigbee2MQTT sends them (with every device's state) the moment
        // the socket opens, and has no request for them. Only the health
        // snapshot needs asking for, or the Home card waits ~10 min for
        // the periodic publish.
        send(topic: Z2MTopics.Request.healthCheck, payload: .string(""))
    }

    private func monitorConnection(config: ConnectionConfig, events: AsyncStream<Z2MSocketEvent>) async {
        guard let reason = await consume(events), !Task.isCancelled else { return }
        store.isConnected = false
        if let newEvents = await reconnect(config: config, reason: reason) {
            await monitorConnection(config: config, events: newEvents)
        }
    }

    /// Applies decoded events a batch at a time (see `Z2MEventBatcher`).
    /// Returns the disconnect reason, or `nil` when cancelled or the socket
    /// ended without one.
    private func consume(_ events: AsyncStream<Z2MSocketEvent>) async -> String? {
        for await batch in Z2MEventBatcher.batches(from: events, router: router) {
            if Task.isCancelled { return nil }
            lastInboundAt = .now
            for item in batch {
                switch item {
                case .message(let data, let event):
                    if let tap = rawInboundTap, let raw = Z2MMessageRouter.decodeRaw(data) {
                        tap(raw.topic, raw.payload)
                    }
                    if let event { store.apply(event) }
                case .disconnected(let reason):
                    return reason
                }
            }
        }
        return nil
    }

    private func reconnect(config: ConnectionConfig, reason: String) async -> AsyncStream<Z2MSocketEvent>? {
        var attempt = 1
        var delay = Self.baseReconnectDelay
        let maxAttempts = Self.configuredMaxReconnectAttempts

        while !Task.isCancelled {
            if attempt > maxAttempts {
                await handleFailure(reason.isEmpty ? "Connection lost" : reason)
                return nil
            }

            connectionState = .reconnecting(attempt: attempt)

            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return nil }

            do {
                let events = try await establishConnection(config: config)
                return events
            } catch is CancellationError {
                return nil
            } catch {
                attempt += 1
                delay = min(delay * 2, Self.maxReconnectDelay)
            }
        }

        return nil
    }

    private func handleFailure(_ message: String) async {
        errorMessage = message
        store.isConnected = false
        let bridgeName = connectionConfig?.displayName ?? "unknown"
        SentryService.shared.recordBridgeEvent("connection failed: \(message)", bridgeName: bridgeName, level: .warning)
        let wasActive = connectionState.isConnected
        let wasReconnecting: Bool
        if case .reconnecting = connectionState { wasReconnecting = true } else { wasReconnecting = false }

        // A failed user-initiated switch: restore the prior bridge as the active
        // connectionConfig so the switcher reads correctly, and force `.failed`
        // semantics (this isn't a network blip — the user explicitly tried to
        // switch). The store still holds the prior bridge's data because
        // establishConnection deferred reset until handshake succeeded.
        if pendingFreshConnect {
            let prior = priorConfigForRestore
            let priorConnected = priorHadConnectedForRestore
            pendingFreshConnect = false
            priorConfigForRestore = nil
            priorHadConnectedForRestore = false

            if let prior {
                connectionConfig = prior
                hasBeenConnected = priorConnected
            } else {
                hasBeenConnected = false
            }
            connectionState = .failed(message)
            return
        }

        connectionState = hasBeenConnected ? .lost(message) : .failed(message)
        if hasBeenConnected && (wasActive || wasReconnecting) {
            postConnectionLostNotification(reason: message)
        }
    }

    private func postConnectionLostNotification(reason: String) {
        let host = connectionConfig?.displayName ?? "bridge"
        let subtitle = reason.isEmpty
            ? "Lost connection to \(host)"
            : "\(host) — \(reason)"
        store.enqueueNotification(InAppNotification(
            level: .error,
            title: "Connection Lost",
            subtitle: subtitle,
            priority: .fastTrack
        ))
    }
}
