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

    // User-configurable preference keys read via UserDefaults (mirrored in
     // AppGeneralView via @AppStorage). Defaults: 3 reconnect attempts, both
     // live activities on.
    static let maxReconnectAttemptsKey = "connectionMaxReconnectAttempts"
    static let connectionLiveActivityEnabledKey = "connectionLiveActivityEnabled"
    static let otaLiveActivityEnabledKey = "otaLiveActivityEnabled"
    static let otaScheduledLiveActivityEnabledKey = "otaScheduledLiveActivityEnabled"
    static let defaultMaxReconnectAttempts: Int = 3
    static let maxReconnectAttemptsRange: ClosedRange<Int> = 1...20
    private static let baseReconnectDelay: Double = 1
    private static let maxReconnectDelay: Double = 30

    static var configuredMaxReconnectAttempts: Int {
        let stored = UserDefaults.standard.integer(forKey: maxReconnectAttemptsKey)
        return stored > 0 ? stored : defaultMaxReconnectAttempts
    }

    static var connectionLiveActivityEnabled: Bool {
        UserDefaults.standard.object(forKey: connectionLiveActivityEnabledKey) as? Bool ?? true
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
        startSession(config: config)
    }

    func retryFromLost() {
        guard let config = connectionConfig else { return }
        errorMessage = nil
        startSession(config: config)
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

    private func prepareForDisconnect() -> Task<Void, Never> {
        sessionTask?.cancel()
        sessionTask = nil
        store.isConnected = false
        connectionState = .idle
        ConnectionLiveActivityCoordinator.shared.cancel()

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
        store.setActiveBridge(config.id)
        history.add(config)
        requestInitialState()
        return events
    }

    private func requestInitialState() {
        // Request full bridge info which includes config if possible
        send(
            topic: Z2MTopics.Request.info,
            payload: .object(["include_device_information": .bool(true)])
        )
        // Pull a fresh health snapshot so the Home card has stats immediately
        // after a (re)connect instead of waiting ~10 min for the periodic publish.
        send(topic: Z2MTopics.Request.healthCheck, payload: .string(""))
        send(topic: Z2MTopics.Request.devices, payload: .string(""))
        send(topic: Z2MTopics.Request.groups, payload: .string(""))
    }

    private func monitorConnection(config: ConnectionConfig, events: AsyncStream<Z2MSocketEvent>) async {
        for await socketEvent in events {
            if Task.isCancelled { return }

            switch socketEvent {
            case .message(let data):
                if let tap = rawInboundTap, let raw = Z2MMessageRouter.decodeRaw(data) {
                    tap(raw.topic, raw.payload)
                }
                if let event = router.route(data) {
                    store.apply(event)
                }
            case .disconnected(let reason):
                store.isConnected = false
                if let newEvents = await reconnect(config: config, reason: reason) {
                    await monitorConnection(config: config, events: newEvents)
                }
                return
            }
        }
    }

    private func reconnect(config: ConnectionConfig, reason: String) async -> AsyncStream<Z2MSocketEvent>? {
        var attempt = 1
        var delay = Self.baseReconnectDelay
        let coordinator = ConnectionLiveActivityCoordinator.shared
        let maxAttempts = Self.configuredMaxReconnectAttempts
        let liveActivityEnabled = Self.connectionLiveActivityEnabled

        if liveActivityEnabled {
            coordinator.show(bridge: config, phase: .reconnecting, attempt: 1, maxAttempts: maxAttempts)
        }

        while !Task.isCancelled {
            if attempt > maxAttempts {
                if liveActivityEnabled {
                    coordinator.finish(.failed, displayFor: 3)
                }
                await handleFailure(reason.isEmpty ? "Connection lost" : reason)
                return nil
            }

            connectionState = .reconnecting(attempt: attempt)

            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return nil }

            do {
                let events = try await establishConnection(config: config)
                if liveActivityEnabled {
                    coordinator.finish(.connected, displayFor: 2.5)
                }
                return events
            } catch is CancellationError {
                return nil
            } catch {
                attempt += 1
                delay = min(delay * 2, Self.maxReconnectDelay)
                if liveActivityEnabled {
                    coordinator.update(phase: .reconnecting, attempt: attempt, maxAttempts: maxAttempts)
                }
            }
        }

        return nil
    }

    private func handleFailure(_ message: String) async {
        errorMessage = message
        store.isConnected = false
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
