import ActivityKit
import SwiftUI
import WidgetKit

struct ConnectionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConnectionActivityAttributes.self) { context in
            ConnectionLockScreenView(context: context)
                .activityBackgroundTint(nil)
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
                    ConnectionExpandedMetric(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: context.attributes.bridgeDisplayName,
                        subtitle: context.state.displayLabel,
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
                ConnectionCompactMetric(state: context.state)
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

private struct ConnectionLockScreenView: View {
    let context: ActivityViewContext<ConnectionActivityAttributes>

    var body: some View {
        LiveActivityLockScreenContent {
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityStatusMark(
                    symbol: context.state.phase.symbol,
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityLockSymbol
                )

                LiveActivityTitleBlock(
                    title: context.attributes.bridgeDisplayName,
                    subtitle: context.state.displayLabel
                )

                Spacer(minLength: DesignTokens.Spacing.sm)
            }
        }
    }
}

private struct ConnectionExpandedMetric: View {
    let state: ConnectionActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .reconnecting:
            LiveActivityMetric(
                value: state.attemptText,
                label: "attempt",
                color: state.phase.accentColor
            )
        case .connected:
            LiveActivityStatusMark(symbol: "checkmark", color: state.phase.accentColor)
        case .failed:
            LiveActivityStatusMark(symbol: "xmark", color: state.phase.accentColor)
        default:
            ProgressView()
                .controlSize(.small)
        }
    }
}

private struct ConnectionCompactMetric: View {
    let state: ConnectionActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .reconnecting:
            LiveActivityMetric(
                value: state.attemptText,
                color: state.phase.accentColor,
                compact: true
            )
        case .connecting:
            ProgressView()
                .controlSize(.mini)
        default:
            EmptyView()
        }
    }
}

private extension ConnectionActivityAttributes.ContentState.Phase {
    var accentColor: Color {
        switch self {
        case .connecting, .reconnecting: return .orange
        case .restarting: return .orange
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
        case .restarting: return "Restarting"
        case .failed: return "Connection failed"
        case .cancelled: return "Cancelled"
        }
    }

    var symbol: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .connecting, .reconnecting: return "wifi"
        case .restarting: return "arrow.clockwise"
        }
    }
}

private extension ConnectionActivityAttributes.ContentState {
    var attemptText: String {
        maxAttempts > 0 ? "\(attempt)/\(maxAttempts)" : "\(attempt)"
    }

    var displayLabel: String {
        message.isEmpty ? phase.label : message
    }
}

private extension ConnectionActivityAttributes.ContentState {
    static let reconnecting2of5 = Self(phase: .reconnecting, attempt: 2, maxAttempts: 5, message: "")
    static let connected = Self(phase: .connected, attempt: 0, maxAttempts: 0, message: "")
    static let failed = Self(phase: .failed, attempt: 0, maxAttempts: 0, message: "")
}

private let previewAttributes = ConnectionActivityAttributes(serverHost: "homelab.local", bridgeDisplayName: "Main")

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
    ConnectionActivityAttributes.ContentState.connected
    ConnectionActivityAttributes.ContentState.failed
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState.reconnecting2of5
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
