import ActivityKit
import Foundation

extension LiveActivityAppearance {
    /// Re-sends every running Live Activity with the app's current look, so
    /// a theme, Card Tint or Themed Indicators change shows at once instead
    /// of on the activity's next update.
    @MainActor
    static func refreshRunningActivities() {
        Task {
            await refresh(PermitJoinActivityAttributes.self) { $0.appearance = .current }
            await refresh(OTAUpdateActivityAttributes.self) { $0.appearance = .current }
            await refresh(BridgeOperationActivityAttributes.self) { $0.appearance = .current }
        }
    }

    private static func refresh<Attributes: ActivityAttributes & Sendable>(
        _: Attributes.Type,
        restamp: (inout Attributes.ContentState) -> Void
    ) async {
        for activity in Activity<Attributes>.activities where activity.activityState == .active {
            var state = activity.content.state
            restamp(&state)
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate,
                                                  relevanceScore: activity.content.relevanceScore))
        }
    }
}
