import SwiftUI

/// Card chrome shared by every device-control card's `.snapshot` rendering.
/// Mirrors `DeviceCard.compact` exactly — same background, same corner radius,
/// same padding — so a log entry stack reads as a stack of consistent rows
/// regardless of whether a row holds a Light, Sensor, Climate, etc. The
/// individual cards are responsible for the *content* of the row (icon +
/// values + optional trailing pill); this view supplies the framing.
///
/// Use it from a card's `mode == .snapshot` body; bypasses the card's
/// interactive-mode chrome (gradients, shadows, large padding) which exists
/// for the controls surface, not the read-only log view.
struct CompactSnapshotCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
            )
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        CompactSnapshotCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.yellow)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Light")
                        .font(.subheadline.weight(.semibold))
                    Text("80% · 2700 K")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("ON")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.yellow.opacity(0.18), in: Capsule())
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
