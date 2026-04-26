import SwiftUI

/// A reusable half-sheet for indexed-group disclosures and any other "deep
/// configuration" surface. Provides the standard iOS chrome — NavigationStack
/// title, Done button, grouped background — and lets the caller render
/// arbitrary rows inside the wrapped card.
struct FeatureDetailSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) { content() }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.lg,
                        style: .continuous
                    ))
                    .padding(DesignTokens.Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// A tappable row that visually matches the inset rows used inside cards but
/// trails with a chevron — signalling that tapping opens a detail sheet.
struct DisclosureFeatureRow: View {
    let symbol: String
    let tint: Color
    let label: String
    let trailingSummary: String?
    let iconTileSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                FeatureIconTile(symbol: symbol, tint: tint, size: iconTileSize)
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if let trailingSummary {
                    Text(trailingSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
