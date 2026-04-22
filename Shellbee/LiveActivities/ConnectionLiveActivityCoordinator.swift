import Foundation

@MainActor
final class ConnectionLiveActivityCoordinator {
    static let shared = ConnectionLiveActivityCoordinator()

    private let controller = LiveActivityController<ConnectionActivityAttributes> {
        (existing: ConnectionActivityAttributes, requested: ConnectionActivityAttributes) in
        existing.serverHost == requested.serverHost
    }

    private init() {}

    func show(host: String, phase: ConnectionActivityAttributes.ContentState.Phase, attempt: Int, maxAttempts: Int) {
        Task {
            await controller.present(
                attributes: ConnectionActivityAttributes(serverHost: host),
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
