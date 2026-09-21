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
        let window = state.startedAt...max(state.startedAt, state.endsAt)
        return Self(
            symbol: "dot.radiowaves.up.forward",
            tint: LiveActivityPalette.pairing,
            title: "Network is open",
            subtitle: joinedText(state.joinedCount),
            value: .countdown(window),
            gauge: .countdown(window)
        )
    }

    static func joinedText(_ count: Int) -> String {
        switch count {
        case 0: return "Waiting for devices"
        case 1: return "1 device joined"
        default: return "\(count) devices joined"
        }
    }
}

private let previewAttributes = PermitJoinActivityAttributes(identifier: "permit-join-preview", bridgeDisplayName: "Main")

private extension PermitJoinActivityAttributes.ContentState {
    static let open = Self(joinedCount: 0, startedAt: .now, endsAt: .now.addingTimeInterval(254), targetName: nil)
    static let joined = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-60), endsAt: .now.addingTimeInterval(194), targetName: nil)
}

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
    PermitJoinActivityAttributes.ContentState.joined
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
