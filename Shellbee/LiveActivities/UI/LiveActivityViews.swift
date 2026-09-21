import SwiftUI
import WidgetKit

// MARK: - Lock Screen

struct LiveActivityLockScreen: View {
    let layout: LiveActivityLayout

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityBadge, pulses: layout.isBusy)

            LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)

            Spacer(minLength: DesignTokens.Spacing.sm)

            LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityValue)
                .layoutPriority(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .background(LiveActivityGlassGradient())
        .activityBackgroundTint(LiveActivityPalette.cardNight)
        .activitySystemActionForegroundColor(.white)
    }
}

/// A near-opaque dark card: graphite at the top-left, deep indigo through the
/// middle, near-black at the bottom-right, finished with a hairline light
/// edge. Opaque enough that the wallpaper never changes how the card reads.
private struct LiveActivityGlassGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: LiveActivityPalette.cardGraphite, location: 0),
                .init(color: LiveActivityPalette.cardIndigo, location: 0.55),
                .init(color: LiveActivityPalette.cardNight, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: DesignTokens.Size.liveActivityCardEdge
                )
        )
    }
}

// MARK: - Dynamic Island regions

// Each region of the island is its own view so the widget's `DynamicIsland`
// and the in-app gallery compose exactly the same content.

struct LiveActivityIslandLeading: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityIslandBadge, pulses: layout.isBusy)
            .padding(.leading, DesignTokens.Spacing.xs)
            .frame(maxHeight: .infinity)
    }
}

struct LiveActivityIslandTrailing: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityValue)
            .padding(.trailing, DesignTokens.Spacing.xs)
            .frame(maxHeight: .infinity)
    }
}

struct LiveActivityIslandBottom: View {
    let layout: LiveActivityLayout

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            LiveActivityTitle(layout: layout, titleFont: .headline, subtitleFont: .subheadline)
            LiveActivityProgressLine(gauge: layout.gauge, tint: layout.tint)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.top, DesignTokens.Spacing.sm)
    }
}

struct LiveActivityCompactLeading: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityGlyph(symbol: layout.symbol, tint: layout.tint, pulses: layout.isBusy)
    }
}

struct LiveActivityCompactTrailing: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityValueView(
            value: layout.compactValue ?? layout.value,
            tint: layout.compactTint ?? layout.tint,
            font: .subheadline.weight(.semibold),
            textColor: layout.compactTint ?? .white
        )
        .contentTransition(.numericText())
    }
}

/// A thin line that drains with the activity's countdown or fills with its
/// progress. Nothing is drawn when there is nothing to measure.
struct LiveActivityProgressLine: View {
    let gauge: LiveActivityGauge
    let tint: Color

    var body: some View {
        switch gauge {
        case .none:
            EmptyView()
        case .progress(let fraction):
            ProgressView(value: min(max(fraction, 0), 1))
                .progressViewStyle(.linear)
                .tint(tint)
        case .countdown(let range):
            ProgressView(timerInterval: range, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(tint)
        }
    }
}

// MARK: - Building blocks

/// Every line stays on one line and shrinks to fit instead of truncating.
/// Wrapping is not an option: the system caps the card's height, and extra
/// lines push the content off-centre.
struct LiveActivityTitle: View {
    let layout: LiveActivityLayout
    let titleFont: Font
    let subtitleFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            if let eyebrow = layout.eyebrow, !eyebrow.isEmpty {
                line(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            line(layout.title)
                .font(titleFont)
                .foregroundStyle(layout.titleTint ?? .white)
            if let subtitle = layout.subtitle, !subtitle.isEmpty {
                line(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            // Long device names may shrink this far before anything is cut.
            .minimumScaleFactor(0.45)
    }
}

struct LiveActivityBadge: View {
    let symbol: String
    let tint: Color
    let size: CGFloat
    var pulses = false

    var body: some View {
        Image(liveActivitySymbol: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.pulse, options: .repeating, isActive: pulses)
            .frame(width: size, height: size)
            .background(tint.opacity(0.2), in: Circle())
            .accessibilityHidden(true)
    }
}

struct LiveActivityGlyph: View {
    let symbol: String
    let tint: Color
    var pulses = false

    var body: some View {
        Image(liveActivitySymbol: symbol)
            .font(.system(size: DesignTokens.Size.liveActivityCompactSymbol, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.pulse, options: .repeating, isActive: pulses)
            .accessibilityHidden(true)
    }
}

struct LiveActivityMinimal: View {
    let layout: LiveActivityLayout

    var body: some View {
        switch layout.gauge {
        case .none:
            LiveActivityGlyph(symbol: layout.symbol, tint: layout.tint)
        case .progress(let fraction):
            ProgressView(value: min(max(fraction, 0), 1)) { glyph }
                .progressViewStyle(.circular)
                .tint(layout.tint)
        case .countdown(let range):
            ProgressView(timerInterval: range, countsDown: true) { glyph } currentValueLabel: { glyph }
                .progressViewStyle(.circular)
                .tint(layout.tint)
        }
    }

    private var glyph: some View {
        Image(liveActivitySymbol: layout.symbol)
            .font(.system(size: DesignTokens.Size.liveActivityMinimalSymbol, weight: .bold))
            .foregroundStyle(layout.tint)
    }
}

/// Renders the live value at a content-sized width. A bare
/// `Text(timerInterval:)` reserves room for the widest possible timer and
/// stretches the Dynamic Island, so countdowns are drawn over a hidden
/// placeholder of the right width instead.
struct LiveActivityValueView: View {
    let value: LiveActivityValue
    let tint: Color
    let font: Font
    var textColor: Color = .white

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .symbol(let name):
            Image(systemName: name)
                .font(font)
                .foregroundStyle(tint)
        case .countdown(let range):
            Text(Self.placeholder(for: range))
                .font(font)
                .monospacedDigit()
                .hidden()
                .overlay(alignment: .trailing) {
                    Text(timerInterval: range, countsDown: true, showsHours: range.duration >= 3600)
                        .font(font)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
        }
    }

    private static func placeholder(for range: ClosedRange<Date>) -> String {
        let seconds = range.duration
        if seconds >= 3600 { return "0:00:00" }
        if seconds >= 600 { return "00:00" }
        return "0:00"
    }
}

extension Image {
    /// Activity symbols may be SF Symbols or the app's own symbol sets, which
    /// the widget catalog carries under the same `shellbee.` prefix.
    init(liveActivitySymbol name: String) {
        if name.hasPrefix("shellbee.") {
            self.init(name)
        } else {
            self.init(systemName: name)
        }
    }
}

private extension ClosedRange where Bound == Date {
    var duration: TimeInterval { upperBound.timeIntervalSince(lowerBound) }
}
