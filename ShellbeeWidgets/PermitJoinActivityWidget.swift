import ActivityKit
import SwiftUI
import WidgetKit

struct PermitJoinActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PermitJoinActivityAttributes.self) { context in
            PermitJoinLockScreenView(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityStatusMark(symbol: "person.badge.plus", color: .orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PermitJoinTimer(context: context, compact: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: "Pairing devices",
                        subtitle: context.state.targetName ?? "Open network",
                        tertiary: context.attributes.bridgeDisplayName,
                        titleFont: .subheadline.weight(.semibold)
                    )
                }
            } compactLeading: {
                LiveActivityStatusMark(
                    symbol: "person.badge.plus",
                    color: .orange,
                    size: DesignTokens.Size.liveActivityCompactSymbol
                )
            } compactTrailing: {
                PermitJoinTimer(context: context, compact: true)
            } minimal: {
                LiveActivityStatusMark(
                    symbol: "person.badge.plus",
                    color: .orange,
                    size: DesignTokens.Size.liveActivityMinimalSymbol
                )
            }
        }
    }
}

private struct PermitJoinLockScreenView: View {
    let context: ActivityViewContext<PermitJoinActivityAttributes>

    var body: some View {
        LiveActivityLockScreenContent {
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityStatusMark(
                    symbol: "person.badge.plus",
                    color: .orange,
                    size: DesignTokens.Size.liveActivityLockSymbol
                )

                LiveActivityTitleBlock(
                    title: "Pairing devices",
                    subtitle: lockScreenDetail
                )

                Spacer(minLength: DesignTokens.Spacing.sm)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    PermitJoinTimer(context: context, compact: false)
                    Text(context.state.joinedCount == 1 ? "1 joined" : "\(context.state.joinedCount) joined")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var lockScreenDetail: String {
        let target = context.state.targetName ?? "Open network"
        return context.attributes.bridgeDisplayName.isEmpty
            ? target
            : "\(target) · \(context.attributes.bridgeDisplayName)"
    }
}

private struct PermitJoinTimer: View {
    let context: ActivityViewContext<PermitJoinActivityAttributes>
    let compact: Bool

    var body: some View {
        Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
            .font((compact ? Font.caption : Font.title3).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

#Preview("Pairing", as: .dynamicIsland(.expanded), using: permitJoinPreviewAttributes) {
    PermitJoinActivityWidget()
} contentStates: {
    PermitJoinActivityAttributes.ContentState(
        joinedCount: 2,
        startedAt: .now,
        endsAt: .now.addingTimeInterval(240),
        targetName: nil
    )
}

private let permitJoinPreviewAttributes = PermitJoinActivityAttributes(
    identifier: "permit-join-preview",
    bridgeDisplayName: "Main"
)
