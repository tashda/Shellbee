import Foundation

@MainActor
final class ConnectionLiveActivityCoordinator {
    static let shared = ConnectionLiveActivityCoordinator()

    private let controller = LiveActivityController<ConnectionActivityAttributes> {
        (existing: ConnectionActivityAttributes, requested: ConnectionActivityAttributes) in
        // Dedup by host+name pair. Same host with different names (multi-bridge
        // use case where two saved bridges live on the same LAN endpoint) gets
        // distinct activities; a reconnect to the same bridge replaces.
        existing.serverHost == requested.serverHost
            && existing.bridgeDisplayName == requested.bridgeDisplayName
    }

    private init() {}

    /// Present an activity for `bridge`. Prefer this over the host-only overload —
    /// it carries the bridge's display name into the attributes.
    func show(bridge: ConnectionConfig, phase: ConnectionActivityAttributes.ContentState.Phase, attempt: Int, maxAttempts: Int) {
        let attributes = ConnectionActivityAttributes(
            serverHost: bridge.host,
            bridgeDisplayName: bridge.displayName
        )
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

    func update(phase: ConnectionActivityAttributes.ContentState.Phase, attempt: Int = 0, maxAttempts: Int = 0) {
        Task {
            await controller.update(
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: attempt,
                    maxAttempts: maxAttempts,
                    message: ""
                )
            )
        }
    }

    func finish(_ phase: ConnectionActivityAttributes.ContentState.Phase, displayFor duration: Double) {
        Task {
            await controller.finish(
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

    func cancel() {
        Task {
            await controller.cancel(
                with: ConnectionActivityAttributes.ContentState(
                    phase: .cancelled,
                    attempt: 0,
                    maxAttempts: 0,
                    message: ""
                )
            )
        }
    }

    func clearAll() {
        Task {
            await LiveActivityController<ConnectionActivityAttributes>.endAllActivities()
        }
    }
}
