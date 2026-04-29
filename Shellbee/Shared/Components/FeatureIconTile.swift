import SwiftUI

/// Settings-app-style colored rounded-square tile with a centered SF Symbol.
/// Used as the leading affordance in feature rows across all device cards.
struct FeatureIconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 30
    var prominent: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * DesignTokens.Ratio.featureTileCorner, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: prominent ? size * DesignTokens.Typography.iconRatioMedium : size * DesignTokens.Typography.iconRatioHalf,
                                  weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}
