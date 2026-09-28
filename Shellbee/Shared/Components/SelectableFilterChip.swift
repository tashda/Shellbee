import SwiftUI

/// A single-choice filter chip in a horizontal row (All, Lights, Sensors).
/// Selected fills with the accent; the rest sit on the row surface.
struct SelectableFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
                .foregroundStyle(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.shellbeeSurface), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
