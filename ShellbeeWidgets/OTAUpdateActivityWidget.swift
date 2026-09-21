import ActivityKit
import SwiftUI
import WidgetKit

struct OTAUpdateActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OTAUpdateActivityAttributes.self) { context in
            LiveActivityLockScreen(layout: .otaUpdate(context))
        } dynamicIsland: { context in
            .blueprint(.otaUpdate(context))
        }
    }
}

private extension LiveActivityLayout {
    static func otaUpdate(_ context: ActivityViewContext<OTAUpdateActivityAttributes>) -> Self {
        let state = context.state
        let symbol = "arrow.down.circle"

        switch state.phase {
        case .active:
            let single = state.activeCount <= 1 ? state.items.first : nil
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.update,
                title: single?.name ?? "\(state.activeCount) updates",
                subtitle: single.map(singleSubtitle) ?? state.detail,
                value: state.progress.map { .text("\($0)%") } ?? .symbol("ellipsis"),
                gauge: state.progress.map { .progress(Double($0) / 100) } ?? .none
            )
        case .completed:
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.success,
                title: state.headline,
                subtitle: state.detail,
                value: .symbol("checkmark.circle.fill")
            )
        case .failed:
            return Self(
                symbol: symbol,
                tint: LiveActivityPalette.failure,
                title: state.headline,
                subtitle: state.detail,
                value: .symbol("xmark.circle.fill")
            )
        }
    }

    static func singleSubtitle(_ item: OTAUpdateActivityAttributes.ContentState.Item) -> String {
        guard let remaining = item.remaining, remaining > 0 else { return "Updating firmware" }
        let text = Duration.seconds(remaining).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1))
        return "About \(text) left"
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
