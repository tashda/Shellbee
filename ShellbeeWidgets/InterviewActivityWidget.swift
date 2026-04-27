import ActivityKit
import SwiftUI
import WidgetKit

struct InterviewActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InterviewActivityAttributes.self) { context in
            InterviewLockScreenView(context: context)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(context.state.phase.accentColor)
                        .symbolEffect(
                            .variableColor.iterative,
                            options: .repeat(.continuous),
                            isActive: context.state.phase == .interviewing
                        )
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    InterviewProgressBadge(state: context.state)
                        .padding(.trailing, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.deviceName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.phase.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(context.state.phase.accentColor)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeat(.continuous),
                        isActive: context.state.phase == .interviewing
                    )
            } compactTrailing: {
                if context.state.phase == .interviewing {
                    ProgressView()
                        .controlSize(.mini)
                }
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.phase.accentColor)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeat(.continuous),
                        isActive: context.state.phase == .interviewing
                    )
            }
        }
    }
}

// MARK: - Lock Screen

private struct InterviewLockScreenView: View {
    let context: ActivityViewContext<InterviewActivityAttributes>

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: context.state.phase.lockSymbol)
                .font(.system(size: 44))
                .foregroundStyle(context.state.phase.accentColor)
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeat(.continuous),
                    isActive: context.state.phase == .interviewing
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.deviceName)
                    .font(.headline)
                Text(context.state.phase.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if context.state.phase == .interviewing {
                ProgressView()
                    .controlSize(.regular)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - Expanded trailing badge

private struct InterviewProgressBadge: View {
    let state: InterviewActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .interviewing:
            ProgressView()
                .controlSize(.small)
        case .successful:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: state.phase)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: state.phase)
        }
    }
}

// MARK: - ContentState helpers

private extension InterviewActivityAttributes.ContentState.Phase {
    var symbol: String {
        switch self {
        case .interviewing: return "waveform.path.ecg"
        case .successful: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var lockSymbol: String {
        switch self {
        case .interviewing: return "waveform.path.ecg.rectangle.fill"
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

    var label: String {
        switch self {
        case .interviewing: return "Interviewing"
        case .successful: return "Interview Successful"
        case .failed: return "Interview Failed"
        }
    }
}

// MARK: - Previews

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
