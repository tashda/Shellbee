import Foundation

/// Phase 2 multi-bridge: every connected bridge gets its own Connection Live
/// Activity. The previous design (singleton controller, single trackedAttributes,
/// `dismissesOtherActivities=true`) silently killed other bridges' activities
/// every time a new one was presented — the controller now runs with
/// `dismissesOtherActivities=false` and update/finish/cancel target a specific
/// bridge's attributes by id.
@MainActor
final class ConnectionLiveActivityCoordinator {
    static let shared = ConnectionLiveActivityCoordinator()

    private let controller = LiveActivityController<ConnectionActivityAttributes>(
        dismissesOtherActivities: false
    ) {
        (existing: ConnectionActivityAttributes, requested: ConnectionActivityAttributes) in
        // Dedup by host+name pair. Two saved bridges on the same LAN endpoint
        // with different names get distinct activities; a reconnect for the
        // same bridge replaces.
        existing.serverHost == requested.serverHost
            && existing.bridgeDisplayName == requested.bridgeDisplayName
    }

    /// Track the most-recently-presented attributes for each bridge so update /
    /// finish / cancel can address them by host+name without the caller having
    /// to construct attributes again.
    private var trackedByBridge: [String: ConnectionActivityAttributes] = [:]

    private init() {}

    /// Present an activity for `bridge`. Existing activities for OTHER bridges
    /// stay alive; only a prior activity for the same bridge is replaced.
    func show(bridge: ConnectionConfig, phase: ConnectionActivityAttributes.ContentState.Phase, attempt: Int, maxAttempts: Int) {
        let attributes = ConnectionActivityAttributes(
            serverHost: bridge.host,
            bridgeDisplayName: bridge.displayName
        )
        let key = trackingKey(for: attributes)
        trackedByBridge[key] = attributes
        Task {
            await controller.present(
                attributes: attributes,
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: attempt,
                    maxAttempts: maxAttempts,
                    message: ""
                )
            )
        }
    }

    /// Update the activity matching `bridge`. Caller passes the same config
    /// they used for `show` so we resolve the right slot.
    func update(bridge: ConnectionConfig, phase: ConnectionActivityAttributes.ContentState.Phase, attempt: Int = 0, maxAttempts: Int = 0) {
        let attributes = ConnectionActivityAttributes(
            serverHost: bridge.host,
            bridgeDisplayName: bridge.displayName
        )
        Task {
            await controller.update(
                attributes: attributes,
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: attempt,
                    maxAttempts: maxAttempts,
                    message: ""
                )
            )
        }
    }

    /// Finish the activity for a specific bridge with a final state.
    func finish(bridge: ConnectionConfig, _ phase: ConnectionActivityAttributes.ContentState.Phase, displayFor duration: Double) {
        let attributes = ConnectionActivityAttributes(
            serverHost: bridge.host,
            bridgeDisplayName: bridge.displayName
        )
        let key = trackingKey(for: attributes)
        trackedByBridge.removeValue(forKey: key)
        Task {
            await controller.finish(
                attributes: attributes,
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: 0,
                    maxAttempts: 0,
                    message: ""
                ),
                displayFor: duration
            )
        }
    }

    /// Cancel a specific bridge's activity (e.g., user disconnected manually).
    func cancel(bridge: ConnectionConfig) {
        let attributes = ConnectionActivityAttributes(
            serverHost: bridge.host,
            bridgeDisplayName: bridge.displayName
        )
        let key = trackingKey(for: attributes)
        trackedByBridge.removeValue(forKey: key)
        Task {
            await controller.cancel(
                attributes: attributes,
                with: ConnectionActivityAttributes.ContentState(
                    phase: .cancelled,
                    attempt: 0,
                    maxAttempts: 0,
                    message: ""
                )
            )
        }
    }

    /// Legacy entry point used by code paths that haven't been migrated to
    /// pass a `ConnectionConfig`. Cancels every tracked activity. Prefer
    /// `cancel(bridge:)` for per-bridge teardown.
    func cancel() {
        let snapshot = Array(trackedByBridge.values)
        trackedByBridge.removeAll()
        Task { [snapshot] in
            for attributes in snapshot {
                await controller.cancel(
                    attributes: attributes,
                    with: ConnectionActivityAttributes.ContentState(
                        phase: .cancelled,
                        attempt: 0,
                        maxAttempts: 0,
                        message: ""
                    )
                )
            }
        }
    }

    func clearAll() {
        trackedByBridge.removeAll()
        Task {
            await LiveActivityController<ConnectionActivityAttributes>.endAllActivities()
        }
    }

    private func trackingKey(for attributes: ConnectionActivityAttributes) -> String {
        "\(attributes.serverHost)|\(attributes.bridgeDisplayName)"
    }
}
