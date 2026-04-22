import ActivityKit
import SwiftUI
import WidgetKit

struct OTAUpdateActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OTAUpdateActivityAttributes.self) { context in
            OTALockScreenView(context: context)
                .activityBackgroundTint(context.state.phase == .failed ? .red.opacity(0.12) : nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.primarySymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            context.state.phase == .failed    ? AnyShapeStyle(.red) :
                            context.state.phase == .completed ? AnyShapeStyle(.green) :
                                                                AnyShapeStyle(.primary)
                        )
                        .symbolEffect(.bounce, value: context.state.phase)
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let progress = context.state.progress {
                        Text("\(progress)%")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(context.state.phase == .failed ? .red : .blue)
                            .contentTransition(.numericText(value: Double(progress)))
                            .padding(.trailing, DesignTokens.Spacing.xs)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.headline)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let progress = context.state.progress, context.state.phase == .active {
                        ProgressView(value: Double(progress), total: 100)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.bottom, DesignTokens.Spacing.sm)
                    }
                }
            } compactLeading: {
                ZStack {
                    if let progress = context.state.progress {
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: Double(progress) / 100)
                            .stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                    }
                    if context.state.activeCount > 1 {
                        Text("\(context.state.activeCount)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: context.state.compactSymbol)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text("\(progress)%")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(progress)))
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                }
            } minimal: {
                OTAProgressRing(
                    progress: context.state.progress,
                    phase: context.state.phase,
                    symbol: "arrow.trianglehead.2.clockwise.circle.fill",
                    size: 22
                )
            }
        }
    }
}

// MARK: - Lock Screen

private struct OTALockScreenView: View {
    let context: ActivityViewContext<OTAUpdateActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: context.state.primarySymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        context.state.phase == .failed    ? AnyShapeStyle(.red) :
                        context.state.phase == .completed ? AnyShapeStyle(.green) :
                                                            AnyShapeStyle(.primary)
                    )
                    .symbolEffect(.bounce, value: context.state.phase)

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.state.headline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(context.state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let progress = context.state.progress {
                    Text("\(progress)%")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(context.state.phase == .failed ? .red : .blue)
                        .contentTransition(.numericText(value: Double(progress)))
                }
            }

            if let progress = context.state.progress, context.state.phase == .active {
                ProgressView(value: Double(progress), total: 100)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - Shared Components

struct OTAProgressRing: View {
    let progress: Int?
    let phase: OTAUpdateActivityAttributes.ContentState.Phase
    let symbol: String
    var size: CGFloat = 40

    private var fraction: Double { progress.map { Double($0) / 100.0 } ?? 0 }
    private var ringColor: Color { phase == .failed ? .red : phase == .completed ? .green : .blue }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.18), lineWidth: size * 0.09)
            if phase == .active {
                if progress != nil {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            LinearGradient(
                                colors: [ringColor, ringColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: fraction)
                } else {
                    Circle()
                        .trim(from: 0.1, to: 0.85)
                        .stroke(ringColor.opacity(0.7), style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            } else {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(ringColor)
                .symbolEffect(.bounce, value: phase)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Previews

private extension OTAUpdateActivityAttributes.ContentState {
    static let singleDevice = Self(
        phase: .active,
        activeCount: 1,
        headline: "1 upgrade running",
        detail: "Kitchen Light • 67%",
        progress: 67,
        items: [
            .init(name: "Kitchen Light", phase: .updating, progress: 67, remaining: 45, categorySymbol: "lightbulb.fill"),
        ]
    )

    static let twoDevices = Self(
        phase: .active,
        activeCount: 2,
        headline: "2 upgrades running",
        detail: "Kitchen Light • 67%",
        progress: 45,
        items: [
            .init(name: "Kitchen Light",   phase: .updating,  progress: 67, remaining: 45,  categorySymbol: "lightbulb.fill"),
            .init(name: "Front Door Lock", phase: .scheduled, progress: nil, remaining: nil, categorySymbol: "lock.fill"),
        ]
    )

    static let fiveDevices = Self(
        phase: .active,
        activeCount: 5,
        headline: "5 upgrades running",
        detail: "Kitchen Light • 67%",
        progress: 38,
        items: [
            .init(name: "Kitchen Light",    phase: .updating,  progress: 67,  remaining: 45,  categorySymbol: "lightbulb.fill"),
            .init(name: "Living Room Plug", phase: .updating,  progress: 23,  remaining: 120, categorySymbol: "poweroutlet.type.b.fill"),
            .init(name: "Front Door Lock",  phase: .scheduled, progress: nil, remaining: nil, categorySymbol: "lock.fill"),
            .init(name: "Thermostat",       phase: .checking,  progress: nil, remaining: nil, categorySymbol: "thermometer"),
            .init(name: "Garage Light",     phase: .requested, progress: nil, remaining: nil, categorySymbol: "lightbulb.fill"),
        ]
    )

    static let manyDevices: Self = {
        let updating: [OTAUpdateActivityAttributes.ContentState.Item] = [
            .init(name: "Kitchen Light",    phase: .updating,  progress: 67, remaining: 45,  categorySymbol: "lightbulb.fill"),
            .init(name: "Living Room Plug", phase: .updating,  progress: 23, remaining: 120, categorySymbol: "poweroutlet.type.b.fill"),
            .init(name: "Bedroom Lamp",     phase: .updating,  progress: 11, remaining: 200, categorySymbol: "lightbulb.fill"),
        ]
        let waiting: [OTAUpdateActivityAttributes.ContentState.Item] = (1...27).map {
            .init(name: "Device \($0)", phase: .scheduled, progress: nil, remaining: nil, categorySymbol: "cpu")
        }
        return Self(
            phase: .active,
            activeCount: 30,
            headline: "30 upgrades running",
            detail: "Kitchen Light • 67%",
            progress: 12,
            items: updating + waiting
        )
    }()

    static let completed = Self(
        phase: .completed,
        activeCount: 0,
        headline: "Upgrade complete",
        detail: "Kitchen Light",
        progress: 100,
        items: [
            .init(name: "Kitchen Light", phase: .idle, progress: 100, remaining: nil, categorySymbol: "lightbulb.fill"),
        ]
    )

    static let failed = Self(
        phase: .failed,
        activeCount: 0,
        headline: "Upgrade failed",
        detail: "Kitchen Light",
        progress: nil,
        items: [
            .init(name: "Kitchen Light", phase: .available, progress: nil, remaining: nil, categorySymbol: "lightbulb.fill"),
        ]
    )
}

private let previewOTAAttributes = OTAUpdateActivityAttributes(identifier: "ota-preview")

#Preview("Lock Screen", as: .content, using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.twoDevices
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.manyDevices
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
    OTAUpdateActivityAttributes.ContentState.twoDevices
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.manyDevices
    OTAUpdateActivityAttributes.ContentState.completed
    OTAUpdateActivityAttributes.ContentState.failed
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewOTAAttributes) {
    OTAUpdateActivityWidget()
} contentStates: {
    OTAUpdateActivityAttributes.ContentState.singleDevice
    OTAUpdateActivityAttributes.ContentState.fiveDevices
    OTAUpdateActivityAttributes.ContentState.completed
}

// MARK: - ContentState helpers

private extension OTAUpdateActivityAttributes.ContentState {
    var primarySymbol: String {
        switch phase {
        case .active:    return "arrow.trianglehead.2.clockwise.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        }
    }

    var compactSymbol: String {
        if activeCount == 1, let sym = items.first?.categorySymbol { return sym }
        return "arrow.trianglehead.2.clockwise.circle.fill"
    }
}
