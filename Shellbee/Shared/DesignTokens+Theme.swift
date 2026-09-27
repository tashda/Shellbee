import CoreGraphics

extension DesignTokens {
    nonisolated enum Theme {
        /// How far down the screen the accent glow reaches before it fades out.
        static let glowHeightFraction: CGFloat = 0.45
        static let glowOpacityLight: Double = 0.14
        static let glowOpacityDark: Double = 0.12
        static let previewHeight: CGFloat = 96
        static let previewRowHeight: CGFloat = 36
        static let previewBarWidth: CGFloat = 72
        static let previewBarHeight: CGFloat = 6
        static let previewBarFill: CGFloat = 44
    }
}
