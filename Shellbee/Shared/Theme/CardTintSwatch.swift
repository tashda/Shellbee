import SwiftUI

/// A card drawn at a fixed Card Tint, for the ends of the Card Tint slider:
/// the untinted card at 0 and the fully tinted card at 1, in the current
/// theme and appearance.
struct CardTintSwatch: View {
    let amount: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Theme.tintSwatchCornerRadius, style: .continuous)
        shape
            .fill(.shellbeeSurface)
            .overlay(shape.strokeBorder(.separator))
            .environment(\.shellbeeSurfaceTint, amount)
            .frame(width: DesignTokens.Theme.tintSwatchWidth, height: DesignTokens.Theme.tintSwatchHeight)
            .accessibilityHidden(true)
    }
}
