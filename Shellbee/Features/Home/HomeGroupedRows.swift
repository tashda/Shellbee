import SwiftUI

/// Home's grouped list: an optional sentence-case title over rows on one
/// rounded surface, like an inset-grouped section.
struct HomeGroupedRows<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DesignTokens.Spacing.lg)
            }
            VStack(spacing: 0) { content }
                .background(
                    .shellbeeSurface,
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
    }
}

extension View {
    /// One row inside `HomeGroupedRows`.
    func homeGroupedRow() -> some View {
        padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.homeRowMinHeight, alignment: .leading)
    }
}
