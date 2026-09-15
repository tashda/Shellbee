import ActivityKit
import SwiftUI
import WidgetKit

struct BridgeDiscoveryActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeDiscoveryActivityAttributes.self) { context in
            BridgeDiscoveryLockScreenView(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityStatusMark(symbol: "dot.radiowaves.left.and.right", color: .primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityMetric(
                        value: "\(context.state.foundCount)",
                        label: "found",
                        color: .primary
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: "Finding bridges",
                        subtitle: context.state.foundCount == 1
                            ? "1 Zigbee2MQTT bridge found"
                            : "\(context.state.foundCount) Zigbee2MQTT bridges found",
                        titleFont: .subheadline.weight(.semibold)
                    )
                }
            } compactLeading: {
                LiveActivityStatusMark(
                    symbol: "dot.radiowaves.left.and.right",
                    color: .primary,
                    size: DesignTokens.Size.liveActivityCompactSymbol
                )
            } compactTrailing: {
                LiveActivityMetric(
                    value: "\(context.state.foundCount)",
                    color: .primary,
                    compact: true
                )
            } minimal: {
                LiveActivityStatusMark(
                    symbol: "dot.radiowaves.left.and.right",
                    color: .primary,
                    size: DesignTokens.Size.liveActivityMinimalSymbol
                )
            }
        }
    }
}

private struct BridgeDiscoveryLockScreenView: View {
    let context: ActivityViewContext<BridgeDiscoveryActivityAttributes>

    var body: some View {
        LiveActivityLockScreenContent {
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityStatusMark(
                    symbol: "dot.radiowaves.left.and.right",
                    color: .primary,
                    size: DesignTokens.Size.liveActivityLockSymbol
                )
                LiveActivityTitleBlock(
                    title: "Finding bridges",
                    subtitle: context.state.foundCount == 1
                        ? "1 Zigbee2MQTT bridge found"
                        : "\(context.state.foundCount) Zigbee2MQTT bridges found"
                )
                Spacer(minLength: DesignTokens.Spacing.sm)
                LiveActivityMetric(
                    value: "\(context.state.foundCount)",
                    label: "found",
                    color: .primary
                )
            }
        }
    }
}

#Preview("Bridge discovery", as: .dynamicIsland(.expanded), using: bridgeDiscoveryPreviewAttributes) {
    BridgeDiscoveryActivityWidget()
} contentStates: {
    BridgeDiscoveryActivityAttributes.ContentState(
        foundCount: 1,
        startedAt: .now,
        endsAt: .now.addingTimeInterval(15)
    )
}

private let bridgeDiscoveryPreviewAttributes = BridgeDiscoveryActivityAttributes()
