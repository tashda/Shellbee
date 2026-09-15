import ActivityKit
import SwiftUI
import WidgetKit

struct InterviewActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InterviewActivityAttributes.self) { context in
            InterviewLockScreenView(context: context)
                .activityBackgroundTint(context.state.phase.backgroundTint)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityStatusMark(
                        symbol: context.state.phase.symbol,
                        color: context.state.phase.accentColor
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    InterviewExpandedMetric(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: context.attributes.deviceName,
                        subtitle: context.state.phase.label,
                        titleFont: .subheadline.weight(.semibold)
                    )
                }
            } compactLeading: {
                LiveActivityStatusMark(
                    symbol: context.state.phase.symbol,
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityCompactSymbol
                )
            } compactTrailing: {
                if context.state.phase == .interviewing {
                    ProgressView()
                        .controlSize(.mini)
                }
            } minimal: {
                LiveActivityStatusMark(
                    symbol: context.state.phase.symbol,
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityMinimalSymbol
                )
            }
        }
    }
}

private struct InterviewLockScreenView: View {
    let context: ActivityViewContext<InterviewActivityAttributes>

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            LiveActivityStatusMark(
                symbol: context.state.phase.symbol,
                color: context.state.phase.accentColor,
                size: DesignTokens.Size.liveActivityLockSymbol
            )

            LiveActivityTitleBlock(
                title: context.attributes.deviceName,
                subtitle: context.state.phase.label
            )

            Spacer(minLength: DesignTokens.Spacing.sm)

            if context.state.phase == .interviewing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

private struct InterviewExpandedMetric: View {
    let state: InterviewActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .interviewing:
            ProgressView()
                .controlSize(.small)
        case .successful:
            LiveActivityStatusMark(symbol: "checkmark", color: state.phase.accentColor)
        case .failed:
            LiveActivityStatusMark(symbol: "xmark", color: state.phase.accentColor)
        }
    }
}

private extension InterviewActivityAttributes.ContentState.Phase {
    var symbol: String {
        switch self {
        case .interviewing: return "antenna.radiowaves.left.and.right"
        case .successful: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .interviewing: return .orange
        case .successful: return .green
        case .failed: return .red
        }
    }

    var backgroundTint: Color? {
        switch self {
        case .interviewing: return .orange.opacity(0.08)
        case .successful: return .green.opacity(0.06)
        case .failed: return .red.opacity(0.08)
        }
    }

    var label: String {
        switch self {
        case .interviewing: return "Interviewing"
        case .successful: return "Interview successful"
        case .failed: return "Interview failed"
        }
    }
}

private extension InterviewActivityAttributes.ContentState {
    static let interviewing = Self(phase: .interviewing)
    static let successful = Self(phase: .successful)
    static let failed = Self(phase: .failed)
}

private let previewAttributes = InterviewActivityAttributes(
    deviceName: "Bedroom Hue",
    ieeeAddress: "0x00158d0001234567"
)

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState.interviewing
    InterviewActivityAttributes.ContentState.successful
    InterviewActivityAttributes.ContentState.failed
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState.interviewing
    InterviewActivityAttributes.ContentState.successful
    InterviewActivityAttributes.ContentState.failed
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState.interviewing
    InterviewActivityAttributes.ContentState.successful
    InterviewActivityAttributes.ContentState.failed
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState.interviewing
    InterviewActivityAttributes.ContentState.successful
    InterviewActivityAttributes.ContentState.failed
}
