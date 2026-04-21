import ActivityKit
import SwiftUI
import WidgetKit

struct OTAUpdateActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OTAUpdateActivityAttributes.self) { context in
            OTALockScreenView(context: context)
                .activityBackgroundTint(context.state.phase == .failed ? .red.opacity(0.12) : .blue.opacity(0.10))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    OTAProgressRing(
                        progress: context.state.progress,
                        phase: context.state.phase,
                        symbol: context.state.primarySymbol,
                        size: 52
                    )
                    .padding(.leading, DesignTokens.Spacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    OTAProgressBadge(
                        progress: context.state.progress,
                        count: context.state.activeCount,
                        phase: context.state.phase
                    )
                    .padding(.trailing, DesignTokens.Spacing.xs)
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
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(context.state.items.prefix(2), id: \.name) { item in
                            OTADeviceProgressRow(item: item)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                }
            } compactLeading: {
                Image(systemName: context.state.compactSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.variableColor.iterative, options: .repeat(.continuous), value: context.state.progress)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text("\(progress)%")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.blue)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                OTAProgressRing(
                    progress: context.state.progress,
                    phase: context.state.phase,
                    symbol: context.state.primarySymbol,
                    size: 46
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.headline)
                        .font(.headline)
                    Text(context.state.detail)
                        .font(.subheadline)
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
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }

            if !context.state.items.isEmpty {
                Rectangle()
                    .fill(.primary.opacity(0.12))
                    .frame(height: 0.5)
                    .padding(.vertical, DesignTokens.Spacing.xs)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(context.state.items, id: \.name) { item in
                        OTADeviceProgressRow(item: item)
                    }
                }
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
                        .animation(.easeInOut(duration: 0.5), value: progress)
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

private struct OTAProgressBadge: View {
    let progress: Int?
    let count: Int
    let phase: OTAUpdateActivityAttributes.ContentState.Phase

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let progress {
                Text("\(progress)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(phase == .failed ? .red : .blue)
                    .contentTransition(.numericText(value: Double(progress)))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.blue)
            }
            if count > 1 {
                Text("\(count) devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OTADeviceProgressRow: View {
    let item: OTAUpdateActivityAttributes.ContentState.Item

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: item.categorySymbol ?? "cpu")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(rowLabel)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(rowLabelColor)
                        .contentTransition(.numericText())
                }
                if let progress = item.progress, item.phase == .updating {
                    ProgressView(value: Double(progress), total: 100)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                } else {
                    ProgressView(value: phaseIndeterminateFraction, total: 1)
                        .progressViewStyle(.linear)
                        .tint(.blue.opacity(0.35))
                }
            }
        }
    }

    private var rowLabel: String {
        switch item.phase {
        case .requested: return "Starting…"
        case .checking:  return "Checking"
        case .scheduled: return "Scheduled"
        case .updating:  return item.progress.map { "\($0)%" } ?? "…"
        case .available: return "Pending"
        case .idle:      return "Done"
        }
    }

    private var rowLabelColor: Color {
        switch item.phase {
        case .idle:      return .green
        case .updating:  return .blue
        default:         return .secondary
        }
    }

    private var phaseIndeterminateFraction: Double {
        switch item.phase {
        case .requested: return 0.05
        case .checking:  return 0.15
        case .scheduled: return 0.25
        default:         return 0
        }
    }
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
