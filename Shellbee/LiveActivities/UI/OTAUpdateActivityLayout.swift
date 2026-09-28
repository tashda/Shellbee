import SwiftUI

extension LiveActivityLayout {
    static func otaUpdate(
        attributes: OTAUpdateActivityAttributes,
        state: OTAUpdateActivityAttributes.ContentState,
        isStale: Bool,
        now: Date = .now
    ) -> Self {
        let symbol = "shellbee.firmware"
        let rows = state.items.map(row)
        let metric = LiveActivityMetric(value: "\(state.activeCount)", label: "Updating")

        switch state.phase {
        case .completed:
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.success,
                eyebrow: attributes.bridgeDisplayName,
                title: state.headline,
                titleTint: LiveActivityPalette.success,
                subtitle: state.detail,
                value: .symbol("checkmark.circle.fill"),
                gauge: .progress(1),
                metric: metric,
                rows: rows,
                style: .otaUpdateDefault
            )
        case .failed:
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.failure,
                eyebrow: attributes.bridgeDisplayName,
                title: state.headline,
                titleTint: LiveActivityPalette.failure,
                subtitle: state.detail,
                value: .symbol("xmark.circle.fill"),
                metric: metric,
                rows: rows,
                style: .otaUpdateDefault
            )
        case .active:
            let single = state.items.count == 1 ? state.items.first : nil
            let running = state.items.first { $0.phase == .updating }
            let window: ClosedRange<Date>? = {
                guard let start = state.progressStart, let end = state.estimatedEnd, end > now else { return nil }
                return min(start, now)...end
            }()
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.update,
                eyebrow: attributes.bridgeDisplayName,
                title: single?.name ?? "\(state.activeCount) updates",
                subtitle: isStale
                    ? "Open Shellbee for the latest progress"
                    : activeSubtitle(single: single, running: running),
                value: window.map { .countdown($0) }
                    ?? state.progress.map { .text("\($0)%") }
                    ?? .symbol("ellipsis"),
                gauge: window.map { .filling($0) }
                    ?? state.progress.map { .progress(Double($0) / 100) }
                    ?? .none,
                isBusy: running != nil,
                metric: metric,
                rows: rows,
                style: .otaUpdateDefault
            )
        }
    }

    private static func activeSubtitle(
        single: OTAUpdateActivityAttributes.ContentState.Item?,
        running: OTAUpdateActivityAttributes.ContentState.Item?
    ) -> String {
        if let single {
            return single.progress.map { "Updating firmware · \($0)%" } ?? status(for: single.phase)
        }
        guard let running else { return "Waiting for devices" }
        return running.progress.map { "\(running.name) · \($0)%" } ?? running.name
    }

    private static func row(_ item: OTAUpdateActivityAttributes.ContentState.Item) -> LiveActivityRow {
        let fraction = item.phase == .updating ? item.progress.map { Double($0) / 100 } : nil
        return LiveActivityRow(
            name: item.name,
            fraction: fraction,
            status: fraction == nil ? status(for: item.phase) : "\(item.progress ?? 0)%"
        )
    }

    private static func status(for phase: OTAUpdateStatus.Phase) -> String {
        switch phase {
        case .updating: return "Updating"
        case .scheduled: return "Scheduled"
        case .requested: return "Starting"
        case .checking: return "Checking"
        case .available, .idle: return "Waiting"
        }
    }
}

extension LiveActivityStyle {
    /// The style the OTA widget renders with.
    static let otaUpdateDefault: LiveActivityStyle = .queue
}
