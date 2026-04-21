import ActivityKit
import SwiftUI
import WidgetKit

struct ConnectionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConnectionActivityAttributes.self) { context in
            lockScreenBanner(context: context)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .symbolVariant(.fill)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    phaseIcon(context.state.phase)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.serverHost)
                            .font(.headline)
                        Text(statusText(for: context.state.phase))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text(context.state.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .symbolVariant(.fill)
                    .foregroundStyle(.tint)
            } compactTrailing: {
                phaseIcon(context.state.phase)
            } minimal: {
                phaseIcon(context.state.phase)
            }
        }
    }

    @ViewBuilder
    private func phaseIcon(_ phase: ConnectionActivityAttributes.ContentState.Phase) -> some View {
        switch phase {
        case .connecting, .reconnecting:
            ProgressView()
                .controlSize(.small)
        case .connected:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: phase)
        case .failed:
            Image(systemName: "xmark")
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: phase)
        case .cancelled:
            Image(systemName: "slash.circle")
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: phase)
        }
    }

    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<ConnectionActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.serverHost)
                    .font(.headline)
                Text(statusText(for: context.state.phase))
                    .font(.subheadline)
                Text(context.state.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            phaseIcon(context.state.phase)
        }
        .padding()
    }

    private func statusText(for phase: ConnectionActivityAttributes.ContentState.Phase) -> String {
        switch phase {
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting"
        case .failed:
            return "Connection Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}
