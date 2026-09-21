import ActivityKit
import Foundation

/// Live Activities outlive app updates. When a kind of activity is retired
/// its widget is gone, so a card left over from the previous version can't
/// render, yet it still occupies the Lock Screen and the Dynamic Island.
/// ActivityKit only lists activities by type, so each retired type keeps a
/// minimal stand-in here (same type name; unknown fields are ignored when
/// decoding) purely so launch can end them.
enum RetiredLiveActivities {
    static func endAll() async {
        for activity in Activity<InterviewActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Retired in 2.0: interviews are shown on the permit join card.
nonisolated struct InterviewActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {}
}
