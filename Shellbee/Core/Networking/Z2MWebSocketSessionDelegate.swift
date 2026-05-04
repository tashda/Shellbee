import Foundation

final class Z2MWebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private enum OpenState {
        case idle
        case waiting(CheckedContinuation<Void, Error>)
        case opened
        case failed(Error)
    }

    private let lock = NSLock()
    private var openState: OpenState = .idle
    private weak var expectedTask: URLSessionWebSocketTask?
    private var allowInvalidCertificates: Bool = false

    func setExpectedTask(_ task: URLSessionWebSocketTask, allowInvalidCertificates: Bool) {
        lock.lock()
        expectedTask = task
        openState = .idle
        self.allowInvalidCertificates = allowInvalidCertificates
        lock.unlock()
    }

    func waitForOpen(timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                guard let self else { throw Z2MError.requestFailed("Connection delegate unavailable.") }
                try await self.awaitOpen()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw Z2MError.timeout
            }

            guard try await group.next() != nil else {
                throw Z2MError.timeout
            }
            group.cancelAll()
        }
    }

    private func awaitOpen() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Resolve any state transition under the lock, then perform side
            // effects (continuation resumes) outside it. The previous
            // implementation overwrote `openState` in the `.waiting` arm but
            // dropped the prior continuation reference — when the websocket
            // later reached `.opened` the stored (already-resumed) new
            // continuation was resumed again, tripping
            // SWIFT TASK CONTINUATION MISUSE.
            var supersededContinuation: CheckedContinuation<Void, Error>? = nil
            let immediateResult: Result<Void, Error>?

            lock.lock()
            switch openState {
            case .idle:
                openState = .waiting(continuation)
                immediateResult = nil
            case .waiting(let prior):
                // Replace the stored continuation with the new one and resume
                // the prior caller with a sentinel error so it unwinds. The
                // new continuation now owns the wait for the actual open.
                supersededContinuation = prior
                openState = .waiting(continuation)
                immediateResult = nil
            case .opened:
                openState = .idle
                immediateResult = .success(())
            case .failed(let error):
                openState = .idle
                immediateResult = .failure(error)
            }
            lock.unlock()

            supersededContinuation?.resume(throwing: Z2MError.requestFailed("Connection attempt replaced."))
            if let immediateResult {
                continuation.resume(with: immediateResult)
            }
        }
    }

    private func resolveOpen(_ result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>?

        lock.lock()
        switch openState {
        case .waiting(let storedContinuation):
            continuation = storedContinuation
            openState = .idle
        case .idle:
            continuation = nil
            switch result {
            case .success:
                openState = .opened
            case .failure(let error):
                openState = .failed(error)
            }
        case .opened, .failed:
            continuation = nil
        }
        lock.unlock()

        if let continuation {
            continuation.resume(with: result)
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard webSocketTask === expectedTask else { return }
        resolveOpen(.success(()))
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        guard webSocketTask === expectedTask else { return }
        resolveOpen(.failure(Z2MError.requestFailed("Connection closed before opening.")))
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        lock.lock()
        let allow = allowInvalidCertificates
        lock.unlock()

        guard allow else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard task === expectedTask else { return }
        if let error {
            resolveOpen(.failure(Z2MError.requestFailed(Z2MError.interpret(error))))
        } else {
            resolveOpen(.failure(Z2MError.requestFailed("Connection ended before opening.")))
        }
    }
}
