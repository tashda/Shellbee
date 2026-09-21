import ActivityKit
import SwiftUI
import WidgetKit

// Every Shellbee Live Activity follows one blueprint: a tinted glyph, a title
// and subtitle, and one large live value, on a glass gradient card. Each
// widget only declares a `LiveActivityLayout`; the views below render it for
// the Lock Screen and every Dynamic Island presentation.

/// The single live value an activity is about.
enum LiveActivityValue {
    case countdown(ClosedRange<Date>)
    case text(String)
    case symbol(String)
}

/// What the minimal island shows: a ring when there's measurable progress.
enum LiveActivityGauge {
    case none
    case progress(Double)
    case countdown(ClosedRange<Date>)
}

enum LiveActivityPalette {
    static let pairing = Color(red: 0.35, green: 0.91, blue: 0.70)
    static let update = Color(red: 0.40, green: 0.70, blue: 1.00)
    static let scan = Color(red: 0.62, green: 0.56, blue: 1.00)
    static let working = Color.orange
    static let success = Color.green
    static let failure = Color.red
    static let neutral = Color.white
}

struct LiveActivityLayout {
    /// The activity's fixed identity icon, shown on the left of the compact
    /// island. It never changes with state: status belongs to `value`, on the
    /// right, so the two sides can never show the same icon.
    let symbol: String
    let tint: Color
    /// Optional context above the title, such as which bridge this is about.
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    /// Tints the subtitle when it reports a problem; otherwise it's muted.
    var subtitleTint: Color? = nil
    let value: LiveActivityValue
    var gauge: LiveActivityGauge = .none
}

// MARK: - Lock Screen

struct LiveActivityLockScreen: View {
    let layout: LiveActivityLayout

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityBadge)

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
        .activityBackgroundTint(Color.black.opacity(0.2))
        .activitySystemActionForegroundColor(.white)
    }
}

/// Light-to-dark wash laid over the system's glass so the card reads as a
/// lit pane of glass rather than a flat slab.
private struct LiveActivityGlassGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.16), Color.black.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Dynamic Island

extension DynamicIsland {
    static func blueprint(_ layout: LiveActivityLayout) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityIslandBadge)
                    .padding(.leading, DesignTokens.Spacing.xs)
            }
            DynamicIslandExpandedRegion(.trailing) {
                LiveActivityValueView(value: layout.value, tint: layout.tint, font: .title2.weight(.semibold))
                    .padding(.trailing, DesignTokens.Spacing.xs)
                    .frame(maxHeight: .infinity)
            }
            DynamicIslandExpandedRegion(.bottom) {
                LiveActivityTitle(layout: layout, titleFont: .subheadline.weight(.semibold), subtitleFont: .caption)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.top, DesignTokens.Spacing.xs)
            }
        } compactLeading: {
            LiveActivityGlyph(symbol: layout.symbol, tint: layout.tint)
        } compactTrailing: {
            LiveActivityValueView(value: layout.value, tint: layout.tint, font: .subheadline.weight(.semibold))
        } minimal: {
            LiveActivityMinimal(layout: layout)
        }
        .keylineTint(layout.tint)
    }
}

// MARK: - Building blocks

/// Every line stays on one line and shrinks to fit instead of truncating.
/// Wrapping is not an option: the system caps the card's height, and extra
/// lines push the content off-centre.
private struct LiveActivityTitle: View {
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
                .foregroundStyle(.white)
            if let subtitle = layout.subtitle, !subtitle.isEmpty {
                line(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(layout.subtitleTint ?? .white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct LiveActivityBadge: View {
    let symbol: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(liveActivitySymbol: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.2), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct LiveActivityGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(liveActivitySymbol: symbol)
            .font(.system(size: DesignTokens.Size.liveActivityCompactSymbol, weight: .semibold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}

private struct LiveActivityMinimal: View {
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
private struct LiveActivityValueView: View {
    let value: LiveActivityValue
    let tint: Color
    let font: Font

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(.white)
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

private extension Image {
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
