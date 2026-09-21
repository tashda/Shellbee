import ActivityKit
import SwiftUI
import WidgetKit

struct InterviewActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InterviewActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .interview(context))
        } dynamicIsland: { context in
            .blueprint(.interview(context))
        }
    }
}

private extension LiveActivityLayout {
    static func interview(_ context: ActivityViewContext<InterviewActivityAttributes>) -> Self {
        let phase = context.state.phase
        return Self(
            symbol: phase.symbol,
            tint: phase.tint,
            title: context.attributes.deviceName,
            subtitle: phase.label,
            value: .symbol(phase.valueSymbol)
        )
    }
}

private extension InterviewActivityAttributes.ContentState.Phase {
    var symbol: String {
        switch self {
        case .interviewing: return "antenna.radiowaves.left.and.right"
        case .successful: return "checkmark"
        case .failed: return "xmark"
        }
    }

    var valueSymbol: String {
        switch self {
        case .interviewing: return "ellipsis"
        case .successful: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .interviewing: return LiveActivityPalette.working
        case .successful: return LiveActivityPalette.success
        case .failed: return LiveActivityPalette.failure
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

private let previewAttributes = InterviewActivityAttributes(deviceName: "Bedroom Hue", ieeeAddress: "0x00158d0001234567")

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState(phase: .interviewing)
    InterviewActivityAttributes.ContentState(phase: .successful)
    InterviewActivityAttributes.ContentState(phase: .failed)
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    InterviewActivityWidget()
} contentStates: {
    InterviewActivityAttributes.ContentState(phase: .interviewing)
}
