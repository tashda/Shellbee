import SwiftUI

extension LiveActivityLayout {
    static func bridgeOperation(
        attributes: BridgeOperationActivityAttributes,
        state: BridgeOperationActivityAttributes.ContentState,
        isStale: Bool
    ) -> Self {
        let operation = attributes.operation
        if operation == .otaCheck {
            return otaCheck(attributes: attributes, state: state)
        }
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

    /// Check All for Updates: how far through the network it is and what
    /// it has found. Progress comes from the app, so a suspended app leaves
    /// the last count showing rather than a guess.
    private static func otaCheck(
        attributes: BridgeOperationActivityAttributes,
        state: BridgeOperationActivityAttributes.ContentState
    ) -> Self {
        let found = LiveActivityMetric(value: "\(state.foundCount)", label: "Found")
        let counts = "\(state.completedCount)/\(state.totalCount)"
        switch state.phase {
        case .active:
            let fraction = state.totalCount > 0 ? Double(state.completedCount) / Double(state.totalCount) : 0
            return Self(
                symbol: "shellbee.firmware",
                tint: LiveActivityPalette.update,
                eyebrow: attributes.bridgeDisplayName,
                title: "Checking for updates",
                subtitle: otaCheckSummary(state, includesProgress: true),
                value: .text(counts),
                gauge: .progress(fraction),
                compactValue: .text("\(counts) · \(state.foundCount) found"),
                isBusy: true,
                metric: found,
                style: .otaCheckDefault
            )
        case .completed, .failed:
            return Self(
                symbol: "shellbee.firmware",
                tint: LiveActivityPalette.success,
                eyebrow: attributes.bridgeDisplayName,
                title: state.phase == .failed ? "Check stopped" : "Check finished",
                subtitle: otaCheckSummary(state, includesProgress: false),
                value: .symbol(state.phase == .failed ? "stop.circle.fill" : "checkmark.circle.fill"),
                metric: found,
                style: .otaCheckDefault
            )
        }
    }

    /// "37 of 142 · 3 updates · 1 no reply", or when finished
    /// "3 updates · 138 up to date · 1 no reply".
    private static func otaCheckSummary(
        _ state: BridgeOperationActivityAttributes.ContentState,
        includesProgress: Bool
    ) -> String {
        var parts: [String] = []
        if includesProgress {
            parts.append("\(state.completedCount) of \(state.totalCount)")
        }
        parts.append(state.foundCount == 1 ? "1 update" : "\(state.foundCount) updates")
        if !includesProgress {
            let upToDate = max(state.completedCount - state.failedCount - state.foundCount, 0)
            parts.append("\(upToDate) up to date")
        }
        if state.failedCount > 0 {
            parts.append("\(state.failedCount) no reply")
        }
        return parts.joined(separator: " · ")
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
        case .otaCheck: return "Checking for updates"
        }
    }

    func finishedTitle(failed: Bool) -> String {
        switch self {
        case .touchlinkScan: return failed ? "Scan failed" : "Scan finished"
        case .touchlinkIdentify: return failed ? "Identify failed" : "Identify finished"
        case .otaCheck: return failed ? "Check stopped" : "Check finished"
        }
    }

    var symbol: String {
        switch self {
        case .touchlinkScan: return "shellbee.touchlink"
        case .touchlinkIdentify: return "shellbee.identify"
        case .otaCheck: return "shellbee.firmware"
        }
    }

    var tint: Color {
        switch self {
        case .touchlinkScan: return LiveActivityPalette.scan
        case .touchlinkIdentify: return LiveActivityPalette.identify
        case .otaCheck: return LiveActivityPalette.update
        }
    }
}

extension LiveActivityStyle {
    /// The styles the Touchlink widget renders with.
    static let touchlinkScanDefault: LiveActivityStyle = .ring
    static let touchlinkIdentifyDefault: LiveActivityStyle = .spotlight
    static let otaCheckDefault: LiveActivityStyle = .track
}
