import ActivityKit
import SwiftUI
import WidgetKit

struct BridgeOperationActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeOperationActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .bridgeOperation(context))
        } dynamicIsland: { context in
            .blueprint(.bridgeOperation(context))
        }
    }
}

private extension LiveActivityLayout {
    static func bridgeOperation(_ context: ActivityViewContext<BridgeOperationActivityAttributes>) -> Self {
        let state = context.state
        let operation = context.attributes.operation
        let window = state.startedAt...max(state.startedAt, state.endsAt)

        switch state.phase {
        case .active:
            return Self(
                symbol: operation.symbol,
                tint: operation.tint,
                title: operation.title,
                subtitle: operation == .touchlinkScan ? foundText(state.foundCount) : (context.attributes.deviceName ?? state.detail),
                value: .countdown(window),
                gauge: .countdown(window)
            )
        case .completed:
            return Self(
                symbol: operation.symbol,
                tint: LiveActivityPalette.success,
                title: operation.title,
                subtitle: state.detail,
                value: .symbol("checkmark.circle.fill")
            )
        case .failed:
            return Self(
                symbol: operation.symbol,
                tint: LiveActivityPalette.failure,
                title: operation.title,
                subtitle: state.detail,
                value: .symbol("xmark.circle.fill")
            )
        }
    }

    static func foundText(_ count: Int) -> String {
        count == 1 ? "1 device found" : "\(count) devices found"
    }
}

private extension BridgeOperationActivityAttributes.Operation {
    var title: String {
        switch self {
        case .touchlinkScan: return "Touchlink scan"
        case .touchlinkIdentify: return "Identifying device"
        }
    }

    var symbol: String {
        switch self {
        case .touchlinkScan: return "dot.radiowaves.left.and.right"
        case .touchlinkIdentify: return "flashlight.on.fill"
        }
    }

    var tint: Color {
        switch self {
        case .touchlinkScan: return LiveActivityPalette.scan
        case .touchlinkIdentify: return .yellow
        }
    }
}

private let scanAttributes = BridgeOperationActivityAttributes(identifier: "touchlinkScan-preview", operation: .touchlinkScan, bridgeDisplayName: "Main")

#Preview("Touchlink scan", as: .content, using: scanAttributes) {
    BridgeOperationActivityWidget()
} contentStates: {
    BridgeOperationActivityAttributes.ContentState(phase: .active, detail: "", foundCount: 3, startedAt: .now, endsAt: .now.addingTimeInterval(30))
    BridgeOperationActivityAttributes.ContentState(phase: .completed, detail: "3 devices found", foundCount: 3, startedAt: .now, endsAt: .now)
}
