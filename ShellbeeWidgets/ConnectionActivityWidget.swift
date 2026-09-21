import ActivityKit
import SwiftUI
import WidgetKit

struct ConnectionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConnectionActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .connection(context))
        } dynamicIsland: { context in
            .blueprint(.connection(context))
        }
    }
}

private extension LiveActivityLayout {
    static func connection(_ context: ActivityViewContext<ConnectionActivityAttributes>) -> Self {
        let state = context.state
        let phase = state.phase
        let attempt = state.maxAttempts > 0 ? "\(state.attempt)/\(state.maxAttempts)" : "\(state.attempt)"
        let showsAttempt = phase == .reconnecting && state.attempt > 0

        return Self(
            symbol: phase.symbol,
            tint: phase.tint,
            title: context.attributes.bridgeDisplayName,
            subtitle: state.message.isEmpty ? phase.label : state.message,
            value: showsAttempt ? .text(attempt) : .symbol(phase.valueSymbol)
        )
    }
}

private extension ConnectionActivityAttributes.ContentState.Phase {
    var tint: Color {
        switch self {
        case .connecting, .reconnecting, .restarting: return LiveActivityPalette.working
        case .connected: return LiveActivityPalette.success
        case .failed: return LiveActivityPalette.failure
        case .cancelled: return LiveActivityPalette.neutral
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
        case .connecting, .reconnecting, .connected: return "wifi"
        case .restarting: return "arrow.clockwise"
        case .failed: return "wifi.exclamationmark"
        case .cancelled: return "wifi.slash"
        }
    }

    var valueSymbol: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .connecting, .reconnecting, .restarting: return "ellipsis"
        }
    }
}

private let previewAttributes = ConnectionActivityAttributes(serverHost: "homelab.local", bridgeDisplayName: "Main")

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState(phase: .reconnecting, attempt: 2, maxAttempts: 5, message: "")
    ConnectionActivityAttributes.ContentState(phase: .connected, attempt: 0, maxAttempts: 0, message: "")
    ConnectionActivityAttributes.ContentState(phase: .failed, attempt: 0, maxAttempts: 0, message: "")
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    ConnectionActivityWidget()
} contentStates: {
    ConnectionActivityAttributes.ContentState(phase: .reconnecting, attempt: 2, maxAttempts: 5, message: "")
}
