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

    private let store: AppStore
    private let history: ConnectionHistory
    private let client = Z2MWebSocketClient()
    private let router = Z2MMessageRouter()

    private var sessionTask: Task<Void, Never>?

    static let maxReconnectAttempts = 5
    private static let baseReconnectDelay: Double = 1
    private static let maxReconnectDelay: Double = 30

    init(store: AppStore, history: ConnectionHistory) {
        self.store = store
        self.history = history
    }

    func connect(config: ConnectionConfig) {
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
            try await establishConnection(config: config)
            await monitorConnection(config: config)
        } catch is CancellationError {
            return
        } catch {
            await handleFailure(Z2MError.interpret(error))
        }
    }

    private func establishConnection(config: ConnectionConfig) async throws {
        guard let url = config.webSocketURL else {
            throw Z2MError.invalidURL
        }

        try await client.connect(url: url)
        config.save()
        connectionState = .connected
        hasBeenConnected = true
        store.isConnected = true
        history.add(config)
        requestInitialState()
    }

    private func requestInitialState() {
        // Request full bridge info which includes config if possible
        send(
            topic: Z2MTopics.Request.info,
            payload: .object(["include_device_information": .bool(true)])
        )
    }

    private func monitorConnection(config: ConnectionConfig) async {
        for await socketEvent in client.events {
            if Task.isCancelled { return }

            switch socketEvent {
            case .message(let data):
                if let event = router.route(data) {
                    store.apply(event)
                }
            case .disconnected(let reason):
                store.isConnected = false
                let recovered = await reconnect(config: config, reason: reason)
                if !recovered { return }
            }
        }
    }

    private func reconnect(config: ConnectionConfig, reason: String) async -> Bool {
        var attempt = 1
        var delay = Self.baseReconnectDelay

        while attempt <= Self.maxReconnectAttempts {
            if Task.isCancelled { return false }

            connectionState = .reconnecting(attempt: attempt)

            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return false }

            do {
                try await establishConnection(config: config)
                return true
            } catch is CancellationError {
                return false
            } catch {
                attempt += 1
                delay = min(delay * 2, Self.maxReconnectDelay)
            }
        }

        await handleFailure(reason.isEmpty ? "Connection lost." : reason)
        return false
    }

    private func handleFailure(_ message: String) async {
        errorMessage = message
        store.isConnected = false
        connectionState = hasBeenConnected ? .lost(message) : .failed(message)
    }
}
