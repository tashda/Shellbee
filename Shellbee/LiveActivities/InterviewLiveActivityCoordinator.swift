import Foundation

@MainActor
final class InterviewLiveActivityCoordinator {
    static let shared = InterviewLiveActivityCoordinator()

    private let controller = LiveActivityController<InterviewActivityAttributes>(
        dismissesOtherActivities: false
    ) { (existing: InterviewActivityAttributes, requested: InterviewActivityAttributes) in
        existing.ieeeAddress == requested.ieeeAddress
    }

    private var tracked: [String: InterviewActivityAttributes] = [:]
    private var expiryTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func start(deviceName: String, ieeeAddress: String) {
        let attributes = InterviewActivityAttributes(deviceName: deviceName, ieeeAddress: ieeeAddress)
        let state = InterviewActivityAttributes.ContentState(phase: .interviewing)
        tracked[ieeeAddress] = attributes
        expiryTasks[ieeeAddress]?.cancel()
        expiryTasks[ieeeAddress] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityInterviewTimeout))
            guard !Task.isCancelled else { return }
            guard let self, self.tracked[ieeeAddress] != nil else { return }
            self.finish(deviceName: deviceName, ieeeAddress: ieeeAddress, success: false)
        }
        Task {
            await controller.present(
                attributes: attributes,
                state: state,
                staleDate: Date.now.addingTimeInterval(DesignTokens.Duration.liveActivityInterviewTimeout),
                relevanceScore: 50
            )
        }
    }

    func finish(deviceName: String, ieeeAddress: String, success: Bool) {
        let attributes = InterviewActivityAttributes(deviceName: deviceName, ieeeAddress: ieeeAddress)
        let state = InterviewActivityAttributes.ContentState(phase: success ? .successful : .failed)
        let duration = success
            ? DesignTokens.Duration.liveActivitySuccess
            : DesignTokens.Duration.liveActivityFailure
        tracked.removeValue(forKey: ieeeAddress)
        expiryTasks.removeValue(forKey: ieeeAddress)?.cancel()
        Task {
            // Ensure controller is tracking this device's attributes before finishing,
            // in case the success/failure event arrives without a prior `start` call
            // in this app session (e.g. interview kicked off before launch).
            await controller.present(attributes: attributes, state: state)
            await controller.finish(attributes: attributes, state: state, displayFor: duration)
        }
    }

    func clearAll() {
        tracked.removeAll()
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
        Task {
            await LiveActivityController<InterviewActivityAttributes>.endAllActivities()
        }
    }
}
