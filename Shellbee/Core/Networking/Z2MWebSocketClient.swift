import Foundation

actor Z2MWebSocketClient {

    private static let connectionTimeout: TimeInterval = 10

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
        task = wsTask
        delegate.setExpectedTask(wsTask)
        wsTask.resume()

        do {
            try await delegate.waitForOpen(timeout: Self.connectionTimeout)
        } catch {
            wsTask.cancel(with: .normalClosure, reason: nil)
            task = nil
            state = .failed(Z2MError.interpret(error))
            continuation.finish()
            currentContinuation = nil
            throw error
        }

        state = .connected
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
