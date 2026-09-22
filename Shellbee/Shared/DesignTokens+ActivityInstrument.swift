import SwiftUI

extension DesignTokens {
    nonisolated enum ActivityInstrument {
        static let size: CGFloat = 48
        static let rowVerticalPadding: CGFloat = DesignTokens.Spacing.sm
        static let rowSpacing: CGFloat = DesignTokens.Spacing.md
        /// Instruments are drawn on a square grid of this many units and
        /// scaled to their frame, so every size shares one drawing.
        static let grid: CGFloat = 48
        /// The value-carrying stroke, in grid units (about 7% of the frame).
        static let markWidth: CGFloat = 3.4
        /// Tracks and empty parts of a gauge, behind the value mark.
        static let trackOpacity: Double = 0.2
        /// The developer stage's mock iOS 26 tab bar, at iPhone scale.
        static let stageTabBarHeight: CGFloat = 62
        static let stageAccessoryHeight: CGFloat = 48
        static let stageMinimizedHeight: CGFloat = 54
        static let stageContentTop: CGFloat = 64
        /// Height of the mock Home Activity section, which doesn't scroll.
        static let stageListHeight: CGFloat = 320
        /// Neighbouring samples shown with the current one, for comparison.
        static let stageNeighbours = 2
    }
}
