import SwiftUI

/// An active filter shown above a list, removed with one tap. Pairs with a
/// filter menu so what's narrowing the list stays visible.
struct RemovableFilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .background(.shellbeeSurface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Removes this filter")
    }
}
