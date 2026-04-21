import ActivityKit
import Foundation

actor LiveActivityController<Attributes: ActivityAttributes & Sendable>
where Attributes.ContentState: Codable & Hashable & Sendable {
    private let matches: @Sendable (Attributes, Attributes) -> Bool
    private let dismissesOtherActivities: Bool
    private var trackedAttributes: Attributes?
    private var endTask: Task<Void, Never>?

    init(
        dismissesOtherActivities: Bool = true,
        matches: @Sendable @escaping (Attributes, Attributes) -> Bool
    ) {
        self.dismissesOtherActivities = dismissesOtherActivities
        self.matches = matches
    }

    func present(attributes: Attributes, state: Attributes.ContentState) async {
        trackedAttributes = attributes
        endTask?.cancel()
        if dismissesOtherActivities {
            await Self.endAllActivitiesImmediately()
        } else {
            await Self.endMatchingActivities(
                for: attributes,
                state: nil,
                matches: matches
            )
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            await Self.updateMatchingActivities(for: attributes, state: state, matches: matches)
        }
    }

    func update(state: Attributes.ContentState) async {
        guard let trackedAttributes else { return }

        await Self.updateMatchingActivities(for: trackedAttributes, state: state, matches: matches)
    }

    func finish(state: Attributes.ContentState, displayFor duration: Double) async {
        guard let trackedAttributes else { return }
        endTask?.cancel()

        await Self.updateMatchingActivities(for: trackedAttributes, state: state, matches: matches)

        endTask = Task {
            let visibleDuration = max(duration, DesignTokens.Duration.liveActivityMinimumVisible)

            try? await Task.sleep(for: .seconds(visibleDuration))
            await Self.endMatchingActivities(
                for: trackedAttributes,
                state: state,
                matches: matches
            )
        }
    }

    func cancel(with state: Attributes.ContentState) async {
        guard let trackedAttributes else { return }
        endTask?.cancel()

        endTask = Task {
            await Self.updateMatchingActivities(for: trackedAttributes, state: state, matches: matches)

            try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityCancel))
            await Self.endMatchingActivities(
                for: trackedAttributes,
                state: state,
                matches: matches
            )
        }
    }

    nonisolated private static func updateMatchingActivities(
        for attributes: Attributes,
        state: Attributes.ContentState,
        matches: @Sendable (Attributes, Attributes) -> Bool
    ) async {
        let activities = Activity<Attributes>.activities.filter { matches($0.attributes, attributes) }
        for activity in activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    nonisolated private static func endMatchingActivities(
        for attributes: Attributes,
        state: Attributes.ContentState?,
        matches: @Sendable (Attributes, Attributes) -> Bool
    ) async {
        let activities = Activity<Attributes>.activities.filter { matches($0.attributes, attributes) }
        for activity in activities {
            if let state {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    nonisolated private static func endAllActivitiesImmediately() async {
        for activity in Activity<Attributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated static func endAllActivities() async {
        await endAllActivitiesImmediately()
    }
}
