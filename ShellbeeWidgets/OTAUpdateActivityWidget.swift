import ActivityKit
import SwiftUI
import WidgetKit

struct OTAUpdateActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OTAUpdateActivityAttributes.self) { context in
            OTALockScreenView(context: context)
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
                    if let progress = context.state.progress, context.state.phase == .active {
                        LiveActivityMetric(
                            value: "\(progress)%",
                            color: context.state.phase.accentColor
                        )
                    } else if context.state.phase == .completed {
                        LiveActivityStatusMark(symbol: "checkmark", color: context.state.phase.accentColor)
                    } else if context.state.phase == .failed {
                        LiveActivityStatusMark(symbol: "xmark", color: context.state.phase.accentColor)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityTitleBlock(
                        title: context.state.headline,
                        subtitle: context.state.detail,
                        tertiary: context.attributes.bridgeDisplayName.isEmpty ? nil : context.attributes.bridgeDisplayName,
                        titleFont: .subheadline.weight(.semibold)
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let progress = context.state.progress, context.state.phase == .active {
                        LiveActivityProgress(progress: progress, tint: context.state.phase.accentColor)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.bottom, DesignTokens.Spacing.sm)
                    }
                }
            } compactLeading: {
                LiveActivityStatusMark(
                    symbol: context.state.phase.symbol,
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityCompactSymbol
                )
            } compactTrailing: {
                if let progress = context.state.progress, context.state.phase == .active {
                    LiveActivityMetric(
                        value: "\(progress)%",
                        color: context.state.phase.accentColor,
                        compact: true
                    )
                } else if context.state.phase == .active {
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

private struct OTALockScreenView: View {
    let context: ActivityViewContext<OTAUpdateActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityStatusMark(
                    symbol: context.state.phase.symbol,
                    color: context.state.phase.accentColor,
                    size: DesignTokens.Size.liveActivityLockSymbol
                )

                LiveActivityTitleBlock(
                    title: context.state.headline,
                    subtitle: context.state.detail,
                    tertiary: context.attributes.bridgeDisplayName.isEmpty ? nil : context.attributes.bridgeDisplayName
                )

                Spacer(minLength: DesignTokens.Spacing.sm)

                if let progress = context.state.progress, context.state.phase == .active {
                    LiveActivityMetric(
                        value: "\(progress)%",
                        color: context.state.phase.accentColor
                    )
                }
            }

            if let progress = context.state.progress, context.state.phase == .active {
                LiveActivityProgress(progress: progress, tint: context.state.phase.accentColor)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

private extension OTAUpdateActivityAttributes.ContentState.Phase {
    var symbol: String {
        switch self {
        case .active: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .active: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var backgroundTint: Color? {
        switch self {
        case .active: return .blue.opacity(0.06)
        case .completed: return .green.opacity(0.06)
        case .failed: return .red.opacity(0.08)
        }
    }
}

private extension OTAUpdateActivityAttributes.ContentState {
    static let singleDevice = Self(
        phase: .active,
        activeCount: 1,
        headline: "Updating",
        detail: "Kitchen Light · 67%",
        progress: 67,
        items: [
            .init(name: "Kitchen Light", phase: .updating, progress: 67, remaining: 45, categorySymbol: "lightbulb.fill")
        ]
    )

    static let fiveDevices = Self(
        phase: .active,
        activeCount: 5,
        headline: "5 device updates",
        detail: "Kitchen Light · 67%",
        progress: 38,
        items: [
            .init(name: "Kitchen Light", phase: .updating, progress: 67, remaining: 45, categorySymbol: "lightbulb.fill"),
            .init(name: "Living Room Plug", phase: .updating, progress: 23, remaining: 120, categorySymbol: "poweroutlet.type.b.fill"),
            .init(name: "Front Door Lock", phase: .scheduled, progress: nil, remaining: nil, categorySymbol: "lock.fill"),
            .init(name: "Thermostat", phase: .checking, progress: nil, remaining: nil, categorySymbol: "thermometer"),
            .init(name: "Garage Light", phase: .requested, progress: nil, remaining: nil, categorySymbol: "lightbulb.fill")
        ]
    )

    static let completed = Self(
        phase: .completed,
        activeCount: 0,
        headline: "Update complete",
        detail: "Kitchen Light",
        progress: 100,
        items: [.init(name: "Kitchen Light", phase: .idle, progress: 100, remaining: nil, categorySymbol: "lightbulb.fill")]
    )

    static let failed = Self(
        phase: .failed,
        activeCount: 0,
        headline: "Update failed",
        detail: "Kitchen Light",
        progress: nil,
        items: [.init(name: "Kitchen Light", phase: .available, progress: nil, remaining: nil, categorySymbol: "lightbulb.fill")]
    )
}

private let previewOTAAttributes = OTAUpdateActivityAttributes(identifier: "ota-preview", bridgeDisplayName: "Main")

#Preview("Lock Screen", as: .content, using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.completed
    OTAUpdateActivityAttributes.ContentState.failed
}

#Preview("Compact", as: .dynamicIsland(.compact), using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.completed
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.completed
    OTAUpdateActivityAttributes.ContentState.failed
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.completed
    OTAUpdateActivityAttributes.ContentState.failed
}
