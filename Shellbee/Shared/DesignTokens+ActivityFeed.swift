import SwiftUI

extension DesignTokens {
    /// Sizes for the Activity Center feed: notification-style cards and
    /// stacks, their thumbnails and outcome pips.
    nonisolated enum ActivityFeed {
        static let thumbnail: CGFloat = 40
        /// Pip diameter as a share of the thumbnail, so it scales from the
        /// 40pt feed card down to the 30pt tab bar artwork.
        /// Bare symbols fill this share of the thumbnail frame; with no
        /// circle behind them they can be larger than the old glyphs.
        static let bareGlyphRatio: CGFloat = 0.62
        /// Z2M link quality runs 0–255.
        static let maxLinkQuality: Double = 255
        static let pipRatio: CGFloat = 0.45
        /// Below this a pip covers too much of the artwork to help.
        static let pipMinimumThumbnail: CGFloat = 24
        static let pipGlyphRatio: CGFloat = 0.5
        static let pipBorder: CGFloat = 2
        static let pipOffsetRatio: CGFloat = 0.075
        /// Sizes the developer icon gallery renders each icon at, from the
        /// smallest inline use up to the feed card.
        static let gallerySizes: [CGFloat] = [13, 15, 20, 30, 40]
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
        /// How far a feed can scroll from its newest entry before it
        /// freezes and offers Follow Live.
        static let liveEdgeTolerance: CGFloat = 24
        /// The grabber that shows the Activity Center can be dragged down.
        static let grabberWidth: CGFloat = 36
        static let grabberHeight: CGFloat = 5
        /// The grabber's touch target: the minimum tap size, so it never
        /// reaches the Filter and Clear Filters capsule beside it.
        static let grabberHitWidth: CGFloat = 44
        /// The inline navigation bar row the grabber is centred in.
        static let navigationBarHeight: CGFloat = 44
        /// How far the grabber has to be pulled down to close.
        static let grabberDismissDistance: CGFloat = 60
        /// Keeps cards readable on iPad and in wide windows.
        static let maxContentWidth: CGFloat = 640
    }

    /// The raw log in the Activity Center: minute cards of compact rows.
    nonisolated enum RawLog {
        static let rowVerticalPadding: CGFloat = 10
        static let tagCornerRadius: CGFloat = 5
    }
}
