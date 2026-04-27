import Foundation
import Network

/// Observes the device's network reachability via `NWPathMonitor`.
///
/// The session controller uses this to react to Wi-Fi loss/return faster than
/// waiting for a WebSocket read to time out. The monitor emits an async stream
/// of transitions so the controller can drop the socket when the network goes
/// away and kick a retry when it comes back.
nonisolated final class NetworkPathMonitor: @unchecked Sendable {

    enum Status: Sendable, Equatable {
        case unknown
        case satisfied
        case unsatisfied
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.shellbee.network-path-monitor")
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Status>.Continuation] = [:]
    private var current: Status = .unknown
    private var started = false

func start() {
        lock.lock()
        if started {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            let next: Status = path.status == .satisfied ? .satisfied : .unsatisfied
            self?.publish(next)
        }
        monitor.start(queue: queue)
    }

private func publish(_ next: Status) {
        lock.lock()
        guard next != current else {
            lock.unlock()
            return
        }
        current = next
        let conts = Array(continuations.values)
        lock.unlock()
        for c in conts { c.yield(next) }
    }

    /// Async stream of status transitions. Each subscriber receives only
    /// changes that occur after subscription.
func updates() -> AsyncStream<Status> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
}
