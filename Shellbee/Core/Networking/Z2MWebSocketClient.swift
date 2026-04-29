import Foundation

actor Z2MWebSocketClient {

    private static let connectionTimeout: TimeInterval = AppConfig.Networking.websocketConnectionTimeout
    /// After the WS handshake succeeds we wait for the *first inbound message*
    /// before declaring the connection valid. Z2M accepts the HTTP 101 upgrade
    /// and only then either (a) immediately publishes the cached bridge state /
    /// device list, or (b) closes the socket with a policy-violation if the
    /// auth token is missing/invalid. Both arrive over the WS — receive() will
    /// return data on success and throw on close. If neither happens within
    /// this timeout, the bridge is unreachable.
    private static let firstMessageTimeout: TimeInterval = AppConfig.Networking.websocketFirstMessageTimeout
    /// Default URLSessionWebSocketTask frame limit is 1 MB. Z2M `bridge/response/backup`
    /// payloads carry the entire data folder as a base64 string inside JSON — a populated
    /// install with many devices and rotated config backups can produce 5–10 MB frames.
    /// Anything beyond this cap aborts the receive loop and disconnects.
    static let maximumFrameSize = 64 * 1024 * 1024

    private let delegate: Z2MWebSocketSessionDelegate
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var currentContinuation: AsyncStream<Z2MSocketEvent>.Continuation?
    private(set) var state: State = .disconnected

    enum State: Sendable {
        case disconnected, connecting, connected, failed(String)
    }

    init() {
        delegate = Z2MWebSocketSessionDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.connectionTimeout
        config.waitsForConnectivity = false
        session = URLSession(
            configuration: config,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func connect(url: URL) async throws -> AsyncStream<Z2MSocketEvent> {
        // Finish any in-progress stream so old for-await loops exit cleanly.
        currentContinuation?.finish()
        currentContinuation = nil

        let (stream, continuation) = AsyncStream.makeStream(of: Z2MSocketEvent.self)
        currentContinuation = continuation

        state = .connecting
        let wsTask = session.webSocketTask(with: url)
        wsTask.maximumMessageSize = Self.maximumFrameSize
        task = wsTask
        delegate.setExpectedTask(wsTask)
        wsTask.resume()

        let firstMessage: URLSessionWebSocketTask.Message
        do {
            try await delegate.waitForOpen(timeout: Self.connectionTimeout)
            firstMessage = try await receiveFirstMessage(wsTask)
        } catch {
            wsTask.cancel(with: .normalClosure, reason: nil)
            task = nil
            state = .failed(Z2MError.interpret(error))
            continuation.finish()
            currentContinuation = nil
            throw error
        }

        state = .connected
        // Replay the validated first message into the stream before starting
        // the regular receive loop, so the session controller sees it.
        if let data = try? Self.extractData(firstMessage) {
            continuation.yield(.message(data))
        }
        receiveLoopTask = Task { await self.receiveLoop(wsTask, continuation: continuation) }
        return stream
    }

    func disconnect() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        state = .disconnected
        currentContinuation?.finish()
        currentContinuation = nil
    }

    func send(_ data: Data) async throws {
        guard let wsTask = task, case .connected = state else { throw Z2MError.notConnected }
        if let string = String(data: data, encoding: .utf8) {
            try await wsTask.send(.string(string))
        } else {
            try await wsTask.send(.data(data))
        }
    }

    private func receiveLoop(_ wsTask: URLSessionWebSocketTask, continuation: AsyncStream<Z2MSocketEvent>.Continuation) async {
        do {
            while true {
                let msg = try await wsTask.receive()
                continuation.yield(.message(try Self.extractData(msg)))
            }
        } catch {
            if Task.isCancelled { return }
            guard case .connected = state else { return }
            state = .failed(error.localizedDescription)
            continuation.yield(.disconnected(error.localizedDescription))
        }
    }

    /// Wait for the first inbound message on the freshly-opened WS, racing
    /// against a timeout. A close frame from the server (e.g. auth rejection)
    /// surfaces as a thrown error from receive(); we re-throw it as a
    /// requestFailed with a clear, user-facing reason.
    private func receiveFirstMessage(_ wsTask: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask {
                do {
                    return try await wsTask.receive()
                } catch {
                    throw Z2MError.requestFailed(Self.describeEarlyClose(error, task: wsTask))
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.firstMessageTimeout))
                throw Z2MError.timeout
            }
            guard let result = try await group.next() else {
                throw Z2MError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    private static func describeEarlyClose(_ error: Error, task: URLSessionWebSocketTask) -> String {
        let code = task.closeCode
        let reason = task.closeReason.flatMap { String(data: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Code 1008 (policy violation) is what Z2M uses for auth rejection.
        // Surface a clear, actionable message instead of the raw close reason.
        if code == .policyViolation {
            if let reason, reason.localizedCaseInsensitiveContains("token") {
                return "Authentication failed: \(reason). Check the auth token."
            }
            return "Server rejected the connection. Check the auth token."
        }

        if let reason, !reason.isEmpty {
            return "Server closed the connection: \(reason)"
        }
        return Z2MError.interpret(error)
    }

    private static func extractData(_ message: URLSessionWebSocketTask.Message) throws -> Data {
        switch message {
        case .data(let d): return d
        case .string(let s):
            guard let d = s.data(using: .utf8) else { throw Z2MError.decodingFailed("UTF-8") }
            return d
        @unknown default: throw Z2MError.decodingFailed("Unknown message type")
        }
    }
}

enum Z2MSocketEvent: Sendable {
    case message(Data)
    case disconnected(String)
}

struct Z2MOutboundEnvelope: Encodable {
    let topic: String
    let payload: JSONValue
}
