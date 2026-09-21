import ActivityKit
import SwiftUI
import WidgetKit

struct PermitJoinActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PermitJoinActivityAttributes.self) { context in
            PermitJoinLockScreenView(context: context)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PermitJoinActivityMark(size: DesignTokens.Size.liveActivityIslandSymbol)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PermitJoinTimer(context: context, compact: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Network is open")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PermitJoinProgress(context: context)
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    PermitJoinActivityMark(size: DesignTokens.Size.liveActivityCompactSymbol)
                    PermitJoinTimer(context: context, compact: true)
                }
            } minimal: {
                PermitJoinActivityMark(size: DesignTokens.Size.liveActivityMinimalSymbol)
            }
        }
    }
}

private struct PermitJoinLockScreenView: View {
    let context: ActivityViewContext<PermitJoinActivityAttributes>

    var body: some View {
        LiveActivityLockScreenContent {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    PermitJoinActivityMark(size: DesignTokens.Size.liveActivityLockSymbol)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text("Network is open")
                            .font(.headline.weight(.semibold))
                        Text(lockScreenDetail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer(minLength: DesignTokens.Spacing.sm)

                    PermitJoinTimer(context: context, compact: false)
                        .layoutPriority(1)
                }
                PermitJoinProgress(context: context)
            }
        }
        .containerBackground(for: .widget) {
            PermitJoinActivityBackground()
        }
    }

    private var lockScreenDetail: String {
        context.state.targetName ?? "Pairing devices"
    }

}

private struct PermitJoinActivityMark: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "dot.radiowaves.up.forward")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(PermitJoinActivityPalette.accent)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct PermitJoinProgress: View {
    let context: ActivityViewContext<PermitJoinActivityAttributes>

    var body: some View {
        ProgressView(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
            .tint(PermitJoinActivityPalette.accent)
    }
}

private struct PermitJoinTimer: View {
    let context: ActivityViewContext<PermitJoinActivityAttributes>
    let compact: Bool

    var body: some View {
        Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
            .font(compact ? .caption.weight(.semibold) : DesignTokens.Typography.liveActivityTimer)
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private enum PermitJoinActivityPalette {
    static let accent = Color(red: 0.35, green: 0.91, blue: 0.70)
}

private struct PermitJoinActivityBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.06, blue: 0.09),
                    Color(red: 0.04, green: 0.12, blue: 0.16),
                    Color(red: 0.06, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PermitJoinActivityPalette.accent.opacity(0.24), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )
        }
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
