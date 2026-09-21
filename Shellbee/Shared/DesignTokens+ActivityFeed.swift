import SwiftUI

extension DesignTokens {
    /// Sizes for the Activity Center feed: notification-style cards and
    /// stacks, their thumbnails and outcome pips.
    nonisolated enum ActivityFeed {
        static let thumbnail: CGFloat = 40
        /// Glyph height as a share of the thumbnail circle. Our symbols
        /// carry their own padding, so this sits above the 46% used by the
        /// older log rows.
        static let glyphRatio: CGFloat = 0.5
        static let pip: CGFloat = 18
        static let pipGlyphRatio: CGFloat = 0.5
        static let pipBorder: CGFloat = 2
        static let pipOffset: CGFloat = 3
        static let cardCornerRadius: CGFloat = 22
        static let cardHorizontalPadding: CGFloat = 14
        static let cardVerticalPadding: CGFloat = 12
        static let cardSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 20
        /// The two slivers that peek out under a collapsed stack.
        static let firstPeekHeight: CGFloat = 8
        static let firstPeekInset: CGFloat = 12
        static let firstPeekOpacity: Double = 0.7
        static let secondPeekHeight: CGFloat = 7
        static let secondPeekInset: CGFloat = 24
        static let secondPeekOpacity: Double = 0.45
        static let peekCornerRadius: CGFloat = 16
        /// Keeps cards readable on iPad and in wide windows.
        static let maxContentWidth: CGFloat = 640
    }
}
