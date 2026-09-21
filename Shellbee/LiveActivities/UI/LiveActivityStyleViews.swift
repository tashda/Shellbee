import SwiftUI
import WidgetKit

// The per-style content. `LiveActivityLockScreen` and the island regions in
// `LiveActivityViews` pick from these by `layout.style`.

// MARK: - Lock Screen content

struct LiveActivityStyledLockContent: View {
    let layout: LiveActivityLayout

    var body: some View {
        switch layout.style {
        case .classic:
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityBadge, pulses: layout.isBusy)
                LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
                Spacer(minLength: DesignTokens.Spacing.sm)
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityValue)
                    .layoutPriority(1)
            }
        case .track:
            TrackContent(layout: layout, valueFont: DesignTokens.Typography.liveActivityValue)
        case .hero:
            HeroContent(layout: layout)
        case .ring:
            HStack(spacing: DesignTokens.Spacing.md) {
                LiveActivityRing(layout: layout, size: DesignTokens.Size.liveActivityRing)
                LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
                Spacer(minLength: DesignTokens.Spacing.sm)
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityValue)
                    .layoutPriority(1)
            }
        case .scoreboard:
            ScoreboardContent(layout: layout)
        }
    }
}

// MARK: - Island regions

struct LiveActivityStyledIslandLeading: View {
    let layout: LiveActivityLayout

    var body: some View {
        switch layout.style {
        case .ring:
            LiveActivityRing(layout: layout, size: DesignTokens.Size.liveActivityIslandBadge)
        case .scoreboard:
            EmptyView()
        default:
            LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityIslandBadge, pulses: layout.isBusy)
        }
    }
}

struct LiveActivityStyledIslandTrailing: View {
    let layout: LiveActivityLayout

    var body: some View {
        switch layout.style {
        case .hero, .scoreboard:
            EmptyView()
        default:
            LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityValue)
        }
    }
}

struct LiveActivityStyledIslandBottom: View {
    let layout: LiveActivityLayout

    var body: some View {
        switch layout.style {
        case .classic:
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
                LiveActivityProgressLine(gauge: layout.gauge, tint: layout.tint)
            }
        case .track:
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
                LiveActivityChunkyBar(gauge: layout.gauge, tint: layout.tint)
            }
        case .hero:
            HeroContent(layout: layout, showsHeader: false)
        case .ring:
            LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
        case .scoreboard:
            ScoreboardContent(layout: layout)
        }
    }
}

// MARK: - Styles

/// Title and countdown on top, a thick track below, the context underneath.
private struct TrackContent: View {
    let layout: LiveActivityLayout
    let valueFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
                Spacer(minLength: DesignTokens.Spacing.sm)
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: valueFont)
                    .layoutPriority(1)
            }
            HStack(spacing: DesignTokens.Spacing.sm) {
                LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityTrackIcon, pulses: layout.isBusy)
                LiveActivityChunkyBar(gauge: layout.gauge, tint: layout.tint)
                if let endsAt = layout.endsAt {
                    Text(endsAt, style: .time)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }
}

/// A parking-meter layout: the countdown is the hero, with its end time.
private struct HeroContent: View {
    let layout: LiveActivityLayout
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if showsHeader {
                HStack {
                    LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityTrackIcon, pulses: layout.isBusy)
                    Text(layout.title)
                        .font(.headline)
                        .foregroundStyle(layout.titleTint ?? .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    if let eyebrow = layout.eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
            }
            HStack(alignment: .lastTextBaseline) {
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityHeroValue)
                Spacer(minLength: DesignTokens.Spacing.sm)
                if let endsAt = layout.endsAt {
                    HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Spacing.xs) {
                        Text("Ends")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(endsAt, style: .time)
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            LiveActivityChunkyBar(gauge: layout.gauge, tint: layout.tint)
            Text(showsHeader ? (layout.subtitle ?? "") : layout.title + (layout.subtitle.map { " · \($0)" } ?? ""))
                .font(.subheadline)
                .foregroundStyle(showsHeader ? .white.opacity(0.6) : (layout.titleTint ?? .white.opacity(0.6)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Three columns, after FotMob's match card: bridge, countdown, joined.
private struct ScoreboardContent: View {
    let layout: LiveActivityLayout

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            column {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            } label: {
                Text(layout.eyebrow.flatMap { $0.isEmpty ? nil : $0 } ?? "Bridge")
            }
            column {
                LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityScoreboardIcon, pulses: layout.isBusy)
            } label: {
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: .title3.weight(.semibold))
            }
            column {
                Text(layout.metric?.value ?? "0")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(layout.tint)
                    .contentTransition(.numericText())
            } label: {
                Text(layout.metric?.label ?? "")
            }
        }
    }

    private func column<Top: View, Label: View>(@ViewBuilder _ top: () -> Top, @ViewBuilder label: () -> Label) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            top().frame(height: DesignTokens.Size.liveActivityScoreboardIcon)
            label()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Building blocks

/// A thick capsule track that drains with the countdown or fills with
/// progress. The system's linear bar is stretched into it, which keeps the
/// system-driven animation that a Live Activity needs.
struct LiveActivityChunkyBar: View {
    let gauge: LiveActivityGauge
    let tint: Color

    var body: some View {
        LiveActivityProgressLine(gauge: gauge, tint: tint)
            .scaleEffect(x: 1, y: DesignTokens.Size.liveActivityChunkyBarScale, anchor: .center)
            .frame(height: DesignTokens.Size.liveActivityChunkyBar)
            .clipShape(Capsule())
    }
}

/// A countdown or progress ring around the activity's icon.
struct LiveActivityRing: View {
    let layout: LiveActivityLayout
    let size: CGFloat
    @Environment(\.isLiveActivityStagePreview) private var isStagePreview

    var body: some View {
        ZStack {
            ring
            LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: size * 0.7, pulses: layout.isBusy)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var ring: some View {
        switch layout.gauge {
        case .none:
            Circle().stroke(layout.tint.opacity(0.25), lineWidth: DesignTokens.Size.liveActivityRingLine)
        case .progress(let fraction):
            drawnRing(fraction)
        case .countdown(let range):
            if isStagePreview {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let total = range.upperBound.timeIntervalSince(range.lowerBound)
                    let left = range.upperBound.timeIntervalSince(context.date)
                    drawnRing(total > 0 ? max(0, min(1, left / total)) : 0)
                }
            } else {
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(layout.tint)
            }
        }
    }

    private func drawnRing(_ fraction: Double) -> some View {
        ZStack {
            Circle().stroke(layout.tint.opacity(0.25), lineWidth: DesignTokens.Size.liveActivityRingLine)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(layout.tint, style: StrokeStyle(lineWidth: DesignTokens.Size.liveActivityRingLine, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
