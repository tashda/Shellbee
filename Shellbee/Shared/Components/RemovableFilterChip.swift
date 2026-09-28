import SwiftUI

/// An active filter shown above a list in a `GlassChipRow`, removed with
/// one tap. Pairs with a filter menu so what's narrowing the list stays
/// visible.
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
            .glassChipLabel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Removes this filter")
    }
}
