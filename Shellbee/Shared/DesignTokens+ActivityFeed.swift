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
        /// Pip diameter as a share of the thumbnail, so it scales from the
        /// 40pt feed card down to the 30pt tab bar artwork.
        static let pipRatio: CGFloat = 0.45
        static let pipGlyphRatio: CGFloat = 0.5
        static let pipBorder: CGFloat = 2
        static let pipOffsetRatio: CGFloat = 0.075
        /// Artwork slot in the tab bar accessory, like the Music mini player.
        static let accessoryArtwork: CGFloat = 30
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
        /// The grabber that shows the Activity Center can be dragged down.
        static let grabberWidth: CGFloat = 36
        static let grabberHeight: CGFloat = 5
        /// Distance from the grabber's bottom edge to the top safe area.
        static let grabberGap: CGFloat = 6
        static let grabberMinimumTop: CGFloat = 6
        /// Keeps cards readable on iPad and in wide windows.
        static let maxContentWidth: CGFloat = 640
    }

    /// The raw log in the Activity Center: minute cards of compact rows.
    nonisolated enum RawLog {
        static let levelMark: CGFloat = 20
        static let levelGlyphRatio: CGFloat = 0.55
        static let quietDot: CGFloat = 6
        static let rowVerticalPadding: CGFloat = 10
        static let tagCornerRadius: CGFloat = 5
    }
}
