import ActivityKit
import SwiftUI
import WidgetKit

struct PermitJoinActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PermitJoinActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .permitJoin(context))
        } dynamicIsland: { context in
            .blueprint(.permitJoin(context))
        }
    }
}

private extension LiveActivityLayout {
    static func permitJoin(_ context: ActivityViewContext<PermitJoinActivityAttributes>) -> Self {
        let state = context.state
        // The app is usually suspended when the window runs out, so it can't
        // end the activity itself. The stale date makes the system re-render
        // here instead, turning a frozen 0:00 into a finished state until the
        // app next runs and ends it.
        if context.isStale || state.endsAt <= .now {
            return Self(
                symbol: "shellbee.permitjoin",
                tint: LiveActivityPalette.neutral,
                eyebrow: context.attributes.bridgeDisplayName,
                title: "Network is closed",
                subtitle: joinedText(state.joinedCount, closed: true),
                value: .symbol("checkmark.circle.fill")
            )
        }
        let window = state.startedAt...max(state.startedAt, state.endsAt)
        let headline = openHeadline(state)
        return Self(
            symbol: "shellbee.permitjoin",
            tint: LiveActivityPalette.pairing,
            eyebrow: context.attributes.bridgeDisplayName,
            title: headline.title,
            subtitle: headline.subtitle,
            subtitleTint: state.interviewFailure == nil ? nil : LiveActivityPalette.failure,
            value: .countdown(window),
            gauge: .countdown(window)
        )
    }

    /// Interview news outranks the pairing window itself: a failure first,
    /// then interviews in progress, then "open" with the joined count. The bee
    /// and the countdown already say the network is open.
    static func openHeadline(_ state: PermitJoinActivityAttributes.ContentState) -> (title: String, subtitle: String) {
        if let failed = state.interviewFailure {
            return ("Interview failed", failed)
        }
        switch state.interviewing.count {
        case 0: return ("Network is open", joinedText(state.joinedCount))
        case 1: return ("Interviewing", state.interviewing[0])
        default: return ("Interviewing", "\(state.interviewing.count) devices")
        }
    }

    static func joinedText(_ count: Int, closed: Bool = false) -> String {
        switch count {
        case 0: return closed ? "No devices joined" : "Waiting for devices"
        case 1: return "1 device joined"
        default: return "\(count) devices joined"
        }
    }
}

private let previewAttributes = PermitJoinActivityAttributes(identifier: "permit-join-preview", bridgeDisplayName: "Main")

private extension PermitJoinActivityAttributes.ContentState {
    static let open = Self(joinedCount: 0, startedAt: .now, endsAt: .now.addingTimeInterval(254), targetName: nil)
    static let joined = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-60), endsAt: .now.addingTimeInterval(194), targetName: nil)
    static let interviewing = Self(joinedCount: 1, startedAt: .now.addingTimeInterval(-30), endsAt: .now.addingTimeInterval(224), targetName: nil, interviewing: ["Hallway Motion Sensor"])
    static let interviewFailed = Self(joinedCount: 1, startedAt: .now.addingTimeInterval(-90), endsAt: .now.addingTimeInterval(164), targetName: nil, interviewFailure: "Kitchen Plug")
    static let closed = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-254), endsAt: .now.addingTimeInterval(-1), targetName: nil)
}

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
    PermitJoinActivityAttributes.ContentState.interviewing
    PermitJoinActivityAttributes.ContentState.interviewFailed
    PermitJoinActivityAttributes.ContentState.joined
    PermitJoinActivityAttributes.ContentState.closed
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.joined
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
}
