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
        for activity in Activity<ConnectionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<BridgeDiscoveryActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Retired in 2.0: interviews are shown on the permit join card.
nonisolated struct InterviewActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {}
}

/// Retired in 2.0: reconnects are shown in the app's own banner.
nonisolated struct ConnectionActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {}
}

/// Retired in 2.0: discovery only runs while the app is on screen.
nonisolated struct BridgeDiscoveryActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {}
}
