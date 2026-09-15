import ActivityKit
import SwiftUI
import WidgetKit

struct BridgeOperationActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeOperationActivityAttributes.self) { context in
            BridgeOperationLockScreenView(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityStatusMark(
                        symbol: context.attributes.operation.symbol(for: context.state.phase),
                        color: context.state.phase.accentColor
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BridgeOperationMetric(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: context.attributes.operation.title,
                        subtitle: context.state.detail,
                        tertiary: context.attributes.bridgeDisplayName.isEmpty ? nil : context.attributes.bridgeDisplayName,
                        titleFont: .subheadline.weight(.semibold)
                    )
                }
            } compactLeading: {
                LiveActivityStatusMark(
                    symbol: context.attributes.operation.symbol(for: context.state.phase),
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityCompactSymbol
                )
            } compactTrailing: {
                if context.attributes.operation == .touchlinkScan, context.state.phase == .active {
                    LiveActivityMetric(
                        value: "\(context.state.foundCount)",
                        color: context.state.phase.accentColor,
                        compact: true
                    )
                } else if context.state.phase == .active {
                    ProgressView()
                        .controlSize(.mini)
                }
            } minimal: {
                LiveActivityStatusMark(
                    symbol: context.attributes.operation.symbol(for: context.state.phase),
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityMinimalSymbol
                )
            }
        }
    }
}

private struct BridgeOperationLockScreenView: View {
    let context: ActivityViewContext<BridgeOperationActivityAttributes>

    var body: some View {
        LiveActivityLockScreenContent {
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityStatusMark(
                    symbol: context.attributes.operation.symbol(for: context.state.phase),
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityLockSymbol
                )

                LiveActivityTitleBlock(
                    title: context.attributes.operation.title,
                    subtitle: lockScreenDetail
                )

                Spacer(minLength: DesignTokens.Spacing.sm)

                BridgeOperationMetric(context: context)
            }
        }
    }

    private var lockScreenDetail: String {
        if context.attributes.bridgeDisplayName.isEmpty {
            return context.state.detail
        }
        return "\(context.state.detail) · \(context.attributes.bridgeDisplayName)"
    }
}

private struct BridgeOperationMetric: View {
    let context: ActivityViewContext<BridgeOperationActivityAttributes>

    var body: some View {
        if context.attributes.operation == .touchlinkScan, context.state.phase == .active {
            LiveActivityMetric(
                value: "\(context.state.foundCount)",
                label: "found",
                color: context.state.phase.accentColor
            )
        } else if context.state.phase == .active {
            ProgressView()
                .controlSize(.small)
        }
    }
}

private extension BridgeOperationActivityAttributes.Operation {
    var title: String {
        switch self {
        case .touchlinkScan: return "Scanning for devices"
        case .touchlinkIdentify: return "Identifying device"
        }
    }

    func symbol(for phase: BridgeOperationActivityAttributes.ContentState.Phase) -> String {
        switch phase {
        case .active:
            switch self {
            case .touchlinkScan: return "dot.radiowaves.left.and.right"
            case .touchlinkIdentify: return "flashlight.on.fill"
            }
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

private extension BridgeOperationActivityAttributes.ContentState.Phase {
    var accentColor: Color {
        switch self {
        case .active: return .primary
        case .completed: return .green
        case .failed: return .red
        }
    }

}

#Preview("Touchlink scan", as: .content, using: bridgeOperationScanPreviewAttributes) {
    BridgeOperationActivityWidget()
} contentStates: {
    BridgeOperationActivityAttributes.ContentState(
        phase: .active,
        detail: "Looking for nearby devices",
        foundCount: 3,
        startedAt: .now,
        endsAt: .now.addingTimeInterval(30)
    )
    BridgeOperationActivityAttributes.ContentState(
        phase: .completed,
        detail: "3 devices found",
        foundCount: 3,
        startedAt: .now,
        endsAt: .now
    )
}

#Preview("Touchlink identify", as: .dynamicIsland(.expanded), using: bridgeOperationIdentifyPreviewAttributes) {
    BridgeOperationActivityWidget()
} contentStates: {
    BridgeOperationActivityAttributes.ContentState(
        phase: .active,
        detail: "Living Room Light",
        foundCount: 0,
        startedAt: .now,
        endsAt: .now.addingTimeInterval(20)
    )
    BridgeOperationActivityAttributes.ContentState(
        phase: .completed,
        detail: "Identify complete",
        foundCount: 0,
        startedAt: .now,
        endsAt: .now
    )
}

private let bridgeOperationScanPreviewAttributes = BridgeOperationActivityAttributes(
    identifier: "touchlinkScan-preview",
    operation: .touchlinkScan,
    bridgeDisplayName: "Main"
)

private let bridgeOperationIdentifyPreviewAttributes = BridgeOperationActivityAttributes(
    identifier: "touchlinkIdentify-preview",
    operation: .touchlinkIdentify,
    bridgeDisplayName: "Main",
    deviceName: "Living Room Light"
)
