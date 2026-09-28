import SwiftUI

/// Greyed-out rows shaped like the list's real rows, shown while the list
/// is loading so it fills in rather than jumping from "No devices" to
/// content. Place inside a `List`, where the real rows would go.
struct LoadingPlaceholderRows: View {
    enum Kind {
        /// Image, name and description, like a device or group row.
        case entity
        /// Icon, title, detail and time, like an activity or log row.
        case event
    }

    var kind: Kind = .entity
    var count = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Placeholder text of varied lengths, so the rows don't read as a grid.
    private static let titles = ["Living room light", "Hall sensor", "Kitchen plug", "Bedroom ceiling lamp", "Front door", "Garden spot"]
    private static let details = ["IKEA · TRADFRI bulb", "Aqara · Motion sensor", "Philips · Hue white", "SONOFF · Contact sensor"]

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            row(index)
                .redacted(reason: .placeholder)
                .phaseAnimator(reduceMotion ? [1.0] : [1.0, DesignTokens.Opacity.loadingPulse]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: DesignTokens.Duration.loadingPulse)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    @ViewBuilder
    private func row(_ index: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                .fill(.quaternary)
                .frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(Self.titles[index % Self.titles.count])
                    .font(.body)
                Text(Self.details[index % Self.details.count])
                    .font(.subheadline)
            }
            Spacer(minLength: 0)
            if kind == .event {
                Text("12:00").font(.caption)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var iconSize: CGFloat {
        kind == .entity ? DesignTokens.Size.deviceRowImage : DesignTokens.Size.summaryRowSymbolFrame
    }
}
