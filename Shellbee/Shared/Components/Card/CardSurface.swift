import SwiftUI

extension View {
    /// The one card style used across device, group and control cards:
    /// secondary grouped background, the inset-grouped List radius and no
    /// shadow. In iOS 26 content sits flat; only the glass control layer
    /// floats above it.
    func cardSurface(padding: CGFloat = DesignTokens.Spacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
            )
    }
}

#Preview {
    Text("Card content")
        .cardSurface()
        .padding()
        .background(Color(.systemGroupedBackground))
}
