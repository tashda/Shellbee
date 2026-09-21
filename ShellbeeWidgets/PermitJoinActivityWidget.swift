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
                symbol: "dot.radiowaves.up.forward",
                tint: LiveActivityPalette.neutral,
                title: "Network is closed",
                subtitle: subtitle(context, closed: true),
                value: .symbol("checkmark.circle.fill")
            )
        }
        let window = state.startedAt...max(state.startedAt, state.endsAt)
        return Self(
            symbol: "dot.radiowaves.up.forward",
            tint: LiveActivityPalette.pairing,
            title: "Network is open",
            subtitle: subtitle(context),
            value: .countdown(window),
            gauge: .countdown(window)
        )
    }

    /// The bridge name is only set when the user has several bridges, so a
    /// single-bridge setup keeps the plain subtitle.
    static func subtitle(_ context: ActivityViewContext<PermitJoinActivityAttributes>, closed: Bool = false) -> String {
        let joined = joinedText(context.state.joinedCount, closed: closed)
        let bridge = context.attributes.bridgeDisplayName
        return bridge.isEmpty ? joined : "\(bridge) · \(joined)"
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
    static let closed = Self(joinedCount: 2, startedAt: .now.addingTimeInterval(-254), endsAt: .now.addingTimeInterval(-1), targetName: nil)
}

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState.open
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
