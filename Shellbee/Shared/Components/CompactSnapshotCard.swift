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

/// Shared content layout for every compact device-control snapshot.
/// Domain cards supply their own state pill, while symbols and text align
/// identically in activity and log detail.
struct CompactControlSnapshotRow<Trailing: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let tint: Color
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: DesignTokens.Size.compactSnapshotSymbol)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.compactSnapshotTextSpacing) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)
            trailing()
        }
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: "lightbulb.fill",
                title: "Light",
                subtitle: "80% · 2700 K",
                tint: .yellow
            ) {
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
