import Foundation
import Network

enum MockBridgeProbe {
    static func isReachable(
        host: String,
        port: Int,
        timeout: TimeInterval = 3
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )
            let gate = ResumeGate()
            let finish: @Sendable (Bool) -> Void = { value in
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                timer.cancel()
                finish(false)
            }
            timer.resume()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timer.cancel()
                    finish(true)
                case .failed, .cancelled:
                    timer.cancel()
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

enum RequiredMockBridgeError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        }
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
