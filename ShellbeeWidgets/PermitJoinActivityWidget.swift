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
        .permitJoin(attributes: context.attributes, state: context.state, isStale: context.isStale)
    }
}

private let previewAttributes = PermitJoinActivityAttributes(identifier: "permit-join-preview", bridgeDisplayName: "Main")

private extension PermitJoinActivityAttributes.ContentState {
    static let open = Self(joinedCount: 0, startedAt: .now, endsAt: .now.addingTimeInterval(254), targetName: nil)
    static let joined = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-60), endsAt: .now.addingTimeInterval(194), targetName: nil)
    static let interviewing = Self(joinedCount: 1, startedAt: .now.addingTimeInterval(-30), endsAt: .now.addingTimeInterval(224), targetName: nil, interviewing: ["Hallway Motion Sensor"])
    static let interviewFailed = Self(joinedCount: 1, startedAt: .now.addingTimeInterval(-90), endsAt: .now.addingTimeInterval(164), targetName: nil, interviewFailure: "Kitchen Plug")
    static let paired = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-60), endsAt: .now.addingTimeInterval(194), targetName: nil, recentlyPaired: "Hallway Motion Sensor")
    static let closed = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-254), endsAt: .now.addingTimeInterval(-1), targetName: nil)
}

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
    PermitJoinActivityAttributes.ContentState.interviewing
    PermitJoinActivityAttributes.ContentState.interviewFailed
    PermitJoinActivityAttributes.ContentState.paired
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
