import ActivityKit
import SwiftUI
import WidgetKit

struct ConnectionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConnectionActivityAttributes.self) { context in
            ConnectionLockScreenView(context: context)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "wifi")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(context.state.phase.accentColor)
                        .symbolEffect(
                            .variableColor.iterative,
                            options: .repeat(.continuous),
                            isActive: context.state.phase == .reconnecting
                        )
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ConnectionProgressBadge(state: context.state)
                        .padding(.trailing, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.serverHost)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.phase.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.compactSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(context.state.phase.accentColor)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeat(.continuous),
                        isActive: context.state.phase == .reconnecting
                    )
                    .symbolEffect(.bounce, value: context.state.phase)
            } compactTrailing: {
                switch context.state.phase {
                case .reconnecting:
                    Text(context.state.maxAttempts > 0 ? "\(context.state.attempt)/\(context.state.maxAttempts)" : "\(context.state.attempt)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(context.state.phase.accentColor)
                case .connecting:
                    ProgressView()
                        .controlSize(.mini)
                default:
                    EmptyView()
                }
            } minimal: {
                Image(systemName: context.state.phase.compactSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.phase.accentColor)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeat(.continuous),
                        isActive: context.state.phase == .reconnecting
                    )
            }
        }
    }
}

// MARK: - Lock Screen

private struct ConnectionLockScreenView: View {
    let context: ActivityViewContext<ConnectionActivityAttributes>

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "wifi.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(context.state.phase.accentColor)
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeat(.continuous),
                    isActive: context.state.phase == .reconnecting
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.serverHost)
                    .font(.headline)
                Text(context.state.phase.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if context.state.phase == .reconnecting {
                    Text(context.state.maxAttempts > 0 ? "Attempt \(context.state.attempt) of \(context.state.maxAttempts)" : "Attempt \(context.state.attempt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if context.state.phase == .reconnecting {
                Text(context.state.maxAttempts > 0 ? "\(context.state.attempt)/\(context.state.maxAttempts)" : "\(context.state.attempt)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(context.state.phase.accentColor)
                    .contentTransition(.numericText(value: Double(context.state.attempt)))
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - Expanded trailing badge

private struct ConnectionProgressBadge: View {
    let state: ConnectionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            switch state.phase {
            case .reconnecting:
                Text(state.maxAttempts > 0 ? "\(state.attempt)/\(state.maxAttempts)" : "\(state.attempt)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(state.phase.accentColor)
                    .contentTransition(.numericText(value: Double(state.attempt)))
                Text("attempts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: state.phase)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: state.phase)
            default:
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Previews

private extension ConnectionActivityAttributes.ContentState {
    static let reconnecting2of5 = Self(phase: .reconnecting, attempt: 2, maxAttempts: 5, message: "")
    static let reconnecting5of5 = Self(phase: .reconnecting, attempt: 5, maxAttempts: 5, message: "")
    static let connected         = Self(phase: .connected,    attempt: 0, maxAttempts: 0, message: "")
    static let failed            = Self(phase: .failed,       attempt: 0, maxAttempts: 0, message: "")
}

private let previewAttributes = ConnectionActivityAttributes(serverHost: "homelab.local")

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
    ConnectionActivityAttributes.ContentState.reconnecting5of5
    ConnectionActivityAttributes.ContentState.connected
    ConnectionActivityAttributes.ContentState.failed
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
    ConnectionActivityAttributes.ContentState.reconnecting5of5
    ConnectionActivityAttributes.ContentState.connected
    ConnectionActivityAttributes.ContentState.failed
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
    ConnectionActivityAttributes.ContentState.connected
    ConnectionActivityAttributes.ContentState.failed
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
    ConnectionActivityAttributes.ContentState.connected
    ConnectionActivityAttributes.ContentState.failed
}

// MARK: - ContentState helpers

private extension ConnectionActivityAttributes.ContentState.Phase {
    var accentColor: Color {
        switch self {
        case .reconnecting, .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    var label: String {
        switch self {
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting"
        case .failed: return "Connection Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var compactSymbol: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .connecting, .reconnecting: return "wifi"
        }
    }
}
