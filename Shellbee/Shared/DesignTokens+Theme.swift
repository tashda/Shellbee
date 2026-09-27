import CoreGraphics

extension DesignTokens {
    nonisolated enum Theme {
        /// How far down the screen the accent glow reaches before it fades out.
        static let glowHeightFraction: CGFloat = 0.45
        static let glowOpacityLight: Double = 0.14
        static let glowOpacityDark: Double = 0.12
        /// How far rows and cards blend at full Card Tint: toward the canvas
        /// in light mode, toward the accent in dark mode.
        static let surfaceReachLight: Double = 0.8
        static let surfaceReachDark: Double = 0.2
        static let previewHeight: CGFloat = 124
        static let previewRowHeight: CGFloat = 38
        static let previewSymbolWidth: CGFloat = 20
        static let previewDividerInset: CGFloat = 40
    }
}
