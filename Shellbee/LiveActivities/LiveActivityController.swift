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

    func present(
        attributes: Attributes,
        state: Attributes.ContentState,
        staleDate: Date? = nil,
        relevanceScore: Double = 0
    ) async {
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
                content: ActivityContent(
                    state: state,
                    staleDate: staleDate,
                    relevanceScore: relevanceScore
                )
            )
        } catch {
            await Self.updateMatchingActivities(
                for: attributes,
                state: state,
                staleDate: staleDate,
                relevanceScore: relevanceScore,
                matches: matches
            )
        }
    }

    func update(
        state: Attributes.ContentState,
        staleDate: Date? = nil,
        relevanceScore: Double = 0
    ) async {
        guard let trackedAttributes else { return }

        await Self.updateMatchingActivities(
            for: trackedAttributes,
            state: state,
            staleDate: staleDate,
            relevanceScore: relevanceScore,
            matches: matches
        )
    }

    /// Multi-activity variant: target the activity whose attributes match
    /// `attributes`, ignoring `trackedAttributes`. Used by Phase 2 multi-bridge
    /// coordinators where N concurrent activities exist (one per bridge) and a
    /// caller must address one specifically rather than the most-recent.
    func update(
        attributes: Attributes,
        state: Attributes.ContentState,
        staleDate: Date? = nil,
        relevanceScore: Double = 0,
        alert: AlertConfiguration? = nil
    ) async {
        await Self.updateMatchingActivities(
            for: attributes,
            state: state,
            staleDate: staleDate,
            relevanceScore: relevanceScore,
            alert: alert,
            matches: matches
        )
    }

    func finish(state: Attributes.ContentState, displayFor duration: Double) async {
        guard let trackedAttributes else { return }
        endTask?.cancel()

        await Self.updateMatchingActivities(for: trackedAttributes, state: state, matches: matches)
        let ids = Self.matchingIDs(for: trackedAttributes, matches: matches)

        endTask = Task {
            let visibleDuration = max(duration, DesignTokens.Duration.liveActivityMinimumVisible)

            try? await Task.sleep(for: .seconds(visibleDuration))
            await Self.endMatchingActivities(
                for: trackedAttributes,
                state: state,
                only: ids,
                matches: matches
            )
        }
    }

    /// Multi-activity variant of `finish` — targets `attributes` directly.
    func finish(attributes: Attributes, state: Attributes.ContentState, displayFor duration: Double) async {
        await Self.updateMatchingActivities(for: attributes, state: state, matches: matches)
        let ids = Self.matchingIDs(for: attributes, matches: matches)

        Task {
            let visibleDuration = max(duration, DesignTokens.Duration.liveActivityMinimumVisible)
            try? await Task.sleep(for: .seconds(visibleDuration))
            await Self.endMatchingActivities(for: attributes, state: state, only: ids, matches: matches)
        }
    }

    func cancel(with state: Attributes.ContentState) async {
        guard let trackedAttributes else { return }
        endTask?.cancel()

        let ids = Self.matchingIDs(for: trackedAttributes, matches: matches)
        endTask = Task {
            await Self.updateMatchingActivities(for: trackedAttributes, state: state, matches: matches)

            try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityCancel))
            await Self.endMatchingActivities(
                for: trackedAttributes,
                state: state,
                only: ids,
                matches: matches
            )
        }
    }

    /// Multi-activity variant of `cancel` — targets `attributes` directly.
    func cancel(attributes: Attributes, with state: Attributes.ContentState) async {
        let ids = Self.matchingIDs(for: attributes, matches: matches)
        Task {
            await Self.updateMatchingActivities(for: attributes, state: state, matches: matches)
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityCancel))
            await Self.endMatchingActivities(for: attributes, state: state, only: ids, matches: matches)
        }
    }

    nonisolated private static func updateMatchingActivities(
        for attributes: Attributes,
        state: Attributes.ContentState,
        staleDate: Date? = nil,
        relevanceScore: Double = 0,
        alert: AlertConfiguration? = nil,
        matches: @Sendable (Attributes, Attributes) -> Bool
    ) async {
        let activities = Activity<Attributes>.activities.filter { matches($0.attributes, attributes) }
        for activity in activities {
            await activity.update(
                ActivityContent(state: state, staleDate: staleDate, relevanceScore: relevanceScore),
                alertConfiguration: alert
            )
        }
    }

    /// Delayed ends snapshot which activities they're ending up front. A
    /// matching activity requested during the delay belongs to new work (a
    /// fresh pairing window, say) and must survive the old one's end.
    nonisolated private static func matchingIDs(
        for attributes: Attributes,
        matches: @Sendable (Attributes, Attributes) -> Bool
    ) -> Set<String> {
        Set(Activity<Attributes>.activities.filter { matches($0.attributes, attributes) }.map(\.id))
    }

    nonisolated private static func endMatchingActivities(
        for attributes: Attributes,
        state: Attributes.ContentState?,
        only ids: Set<String>? = nil,
        matches: @Sendable (Attributes, Attributes) -> Bool
    ) async {
        let activities = Activity<Attributes>.activities.filter {
            matches($0.attributes, attributes) && (ids?.contains($0.id) ?? true)
        }
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
