import ActivityKit
import SwiftUI
import WidgetKit

struct BridgeDiscoveryActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeDiscoveryActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .bridgeDiscovery(context))
        } dynamicIsland: { context in
            .blueprint(.bridgeDiscovery(context))
        }
    }
}

private extension LiveActivityLayout {
    static func bridgeDiscovery(_ context: ActivityViewContext<BridgeDiscoveryActivityAttributes>) -> Self {
        let count = context.state.foundCount
        return Self(
            symbol: "magnifyingglass",
            tint: LiveActivityPalette.scan,
            title: "Finding bridges",
            subtitle: count == 1 ? "1 bridge found" : "\(count) bridges found",
            value: .text("\(count)"),
            gauge: .countdown(context.state.startedAt...max(context.state.startedAt, context.state.endsAt))
        )
    }
}

private let previewAttributes = BridgeDiscoveryActivityAttributes()

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    BridgeDiscoveryActivityWidget()
} contentStates: {
    BridgeDiscoveryActivityAttributes.ContentState(foundCount: 1, startedAt: .now, endsAt: .now.addingTimeInterval(15))
}
