import Foundation
import os

/// Decodes a socket's frames off the main actor and hands them over in
/// batches, so a burst (the hundreds of retained messages Zigbee2MQTT sends
/// on connect) is applied to the store in a few main-actor turns instead of
/// one turn, and one SwiftUI update, per message.
///
/// A message after a quiet spell (a device answering a tap) is handed over
/// at once; only messages arriving within `window` of the last hand-over
/// wait to be batched. Order is kept: one task decodes frames in arrival
/// order, and each hand-over yields everything received so far.
nonisolated enum Z2MEventBatcher {
    enum Item: Sendable {
        /// `data` is kept for the MQTT inspector's raw tap.
        case message(data: Data, event: Z2MEvent?)
        case disconnected(String)
    }

    /// How long a batch collects before it's applied. Short enough that a
    /// tap's echo feels immediate, long enough to gather a burst.
    static let window: Duration = .milliseconds(40)

    static func batches(
        from events: AsyncStream<Z2MSocketEvent>,
        router: Z2MMessageRouter
    ) -> AsyncStream<[Item]> {
        AsyncStream { continuation in
            let buffer = Buffer(continuation: continuation)
            let task = Task.detached(priority: .userInitiated) {
                for await event in events {
                    switch event {
                    case .message(let data):
                        buffer.append(.message(data: data, event: router.route(data)))
                    case .disconnected(let reason):
                        buffer.append(.disconnected(reason))
                        buffer.finish()
                        return
                    }
                }
                buffer.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private final class Buffer: Sendable {
        private struct State: Sendable {
            var items: [Item] = []
            var flushScheduled = false
            var finished = false
            var lastYield: ContinuousClock.Instant?
        }

        private let state = OSAllocatedUnfairLock(initialState: State())
        private let continuation: AsyncStream<[Item]>.Continuation

        init(continuation: AsyncStream<[Item]>.Continuation) {
            self.continuation = continuation
        }

        func append(_ item: Item) {
            let needsFlush = state.withLock { state -> Bool in
                guard !state.finished else { return false }
                let now = ContinuousClock.now
                let quiet = state.lastYield.map { now - $0 >= Z2MEventBatcher.window } ?? true
                if quiet, !state.flushScheduled, state.items.isEmpty {
                    continuation.yield([item])
                    state.lastYield = now
                    return false
                }
                state.items.append(item)
                guard !state.flushScheduled else { return false }
                state.flushScheduled = true
                return true
            }
            guard needsFlush else { return }
            Task.detached { [self] in
                try? await Task.sleep(for: Z2MEventBatcher.window)
                flush()
            }
        }

        /// Yields inside the lock so a batch can never land after `finish`.
        func flush() {
            state.withLock { state in
                state.flushScheduled = false
                guard !state.finished, !state.items.isEmpty else { return }
                continuation.yield(state.items)
                state.items.removeAll(keepingCapacity: true)
                state.lastYield = ContinuousClock.now
            }
        }

        func finish() {
            state.withLock { state in
                guard !state.finished else { return }
                if !state.items.isEmpty { continuation.yield(state.items) }
                state.items.removeAll()
                state.finished = true
                continuation.finish()
            }
        }
    }
}
