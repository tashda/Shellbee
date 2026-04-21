import Foundation

@MainActor
final class ConnectionLiveActivityCoordinator {
    static let shared = ConnectionLiveActivityCoordinator()

    private let controller = LiveActivityController<ConnectionActivityAttributes> {
        (existing: ConnectionActivityAttributes, requested: ConnectionActivityAttributes) in
        existing.serverHost == requested.serverHost
    }

    private init() {}

    func show(host: String, phase: ConnectionActivityAttributes.ContentState.Phase, message: String) {
        Task {
            await controller.present(
                attributes: ConnectionActivityAttributes(serverHost: host),
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: 0,
                    message: message
                )
            )
        }
    }

    func update(
        phase: ConnectionActivityAttributes.ContentState.Phase,
        attempt: Int = 0,
        message: String
    ) {
        Task {
            await controller.update(
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: attempt,
                    message: message
                )
            )
        }
    }

    func finish(
        _ phase: ConnectionActivityAttributes.ContentState.Phase,
        message: String,
        displayFor duration: Double
    ) {
        Task {
            await controller.finish(
                state: ConnectionActivityAttributes.ContentState(
                    phase: phase,
                    attempt: 0,
                    message: message
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
                    message: "Cancelled"
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
