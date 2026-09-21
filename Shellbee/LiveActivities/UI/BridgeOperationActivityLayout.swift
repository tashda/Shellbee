import SwiftUI

extension LiveActivityLayout {
    static func bridgeOperation(
        attributes: BridgeOperationActivityAttributes,
        state: BridgeOperationActivityAttributes.ContentState,
        isStale: Bool
    ) -> Self {
        let operation = attributes.operation
        let window = state.startedAt...max(state.startedAt, state.endsAt)
        let found = LiveActivityMetric(value: "\(state.foundCount)", label: "Found")
        let style: LiveActivityStyle = operation == .touchlinkScan ? .touchlinkScanDefault : .touchlinkIdentifyDefault

        if state.phase == .active, !isStale, state.endsAt > .now {
            return Self(
                symbol: operation.symbol,
                tint: operation.tint,
                eyebrow: attributes.bridgeDisplayName,
                title: operation.title,
                subtitle: operation == .touchlinkScan
                    ? foundText(state.foundCount)
                    : (attributes.deviceName ?? state.detail),
                value: .countdown(window),
                gauge: .countdown(window),
                isBusy: true,
                metric: operation == .touchlinkScan ? found : nil,
                style: style
            )
        }
        // Time ran out while the app was suspended, so the result never
        // reached the card. Say so instead of implying an empty result.
        if state.phase == .active {
            return Self(
                symbol: operation.symbol,
                tint: LiveActivityPalette.neutral,
                eyebrow: attributes.bridgeDisplayName,
                title: operation.finishedTitle(failed: false),
                subtitle: "Open Shellbee to see the result",
                value: .symbol("arrow.up.forward.app.fill"),
                metric: operation == .touchlinkScan ? found : nil,
                style: style
            )
        }
        let failed = state.phase == .failed
        return Self(
            symbol: operation.symbol,
            tint: failed ? LiveActivityPalette.failure : LiveActivityPalette.success,
            eyebrow: attributes.bridgeDisplayName,
            title: operation.finishedTitle(failed: failed),
            titleTint: failed ? LiveActivityPalette.failure : LiveActivityPalette.success,
            subtitle: operation == .touchlinkScan && !failed ? foundText(state.foundCount) : state.detail,
            value: .symbol(failed ? "xmark.circle.fill" : "checkmark.circle.fill"),
            metric: operation == .touchlinkScan ? found : nil,
            style: style
        )
    }

    private static func foundText(_ count: Int) -> String {
        switch count {
        case 0: return "Looking for nearby devices"
        case 1: return "1 device found"
        default: return "\(count) devices found"
        }
    }
}

private extension BridgeOperationActivityAttributes.Operation {
    var title: String {
        switch self {
        case .touchlinkScan: return "Touchlink scan"
        case .touchlinkIdentify: return "Identifying"
        }
    }

    func finishedTitle(failed: Bool) -> String {
        switch self {
        case .touchlinkScan: return failed ? "Scan failed" : "Scan finished"
        case .touchlinkIdentify: return failed ? "Identify failed" : "Identify finished"
        }
    }

    var symbol: String {
        switch self {
        case .touchlinkScan: return "shellbee.touchlink"
        case .touchlinkIdentify: return "shellbee.identify"
        }
    }

    var tint: Color {
        switch self {
        case .touchlinkScan: return LiveActivityPalette.scan
        case .touchlinkIdentify: return LiveActivityPalette.identify
        }
    }
}

extension LiveActivityStyle {
    /// The styles the Touchlink widget renders with.
    static let touchlinkScanDefault: LiveActivityStyle = .ring
    static let touchlinkIdentifyDefault: LiveActivityStyle = .spotlight
}
