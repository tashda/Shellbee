import Foundation

@MainActor
final class InterviewLiveActivityCoordinator {
    static let shared = InterviewLiveActivityCoordinator()

    private let controller = LiveActivityController<InterviewActivityAttributes>(
        dismissesOtherActivities: false
    ) { (existing: InterviewActivityAttributes, requested: InterviewActivityAttributes) in
        existing.ieeeAddress == requested.ieeeAddress
    }

    private init() {}

    func start(deviceName: String, ieeeAddress: String) {
        let attributes = InterviewActivityAttributes(deviceName: deviceName, ieeeAddress: ieeeAddress)
        let state = InterviewActivityAttributes.ContentState(phase: .interviewing)
        Task {
            await controller.present(attributes: attributes, state: state)
        }
    }

    func finish(deviceName: String, ieeeAddress: String, success: Bool) {
        let attributes = InterviewActivityAttributes(deviceName: deviceName, ieeeAddress: ieeeAddress)
        let state = InterviewActivityAttributes.ContentState(phase: success ? .successful : .failed)
        let duration = success
            ? DesignTokens.Duration.liveActivitySuccess
            : DesignTokens.Duration.liveActivityFailure
        Task {
            // Ensure controller is tracking this device's attributes before finishing,
            // in case the success/failure event arrives without a prior `start` call
            // in this app session (e.g. interview kicked off before launch).
            await controller.present(attributes: attributes, state: state)
            await controller.finish(state: state, displayFor: duration)
        }
    }
}
