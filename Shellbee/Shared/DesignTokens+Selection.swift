import SwiftUI

extension DesignTokens {
    nonisolated enum Count {
        static let liveActivityQueueRows = 3
        /// Most options a segmented control holds before a menu takes over.
        static let segmentedMaxOptions = 4
    }
}

/// Tokens for compact selection rows and Activity feed affordances.
extension DesignTokens.Spacing {
    static let summaryRowTextSpacing: CGFloat = 3
    static let summaryRowVerticalPadding: CGFloat = 2
    static let compactSnapshotTextSpacing: CGFloat = 2
    static let bridgeLogRowVerticalInset: CGFloat = 6
    static let bridgeLogRowHorizontalInset: CGFloat = 16
}

extension DesignTokens.Size {
    static let activityClearButton: CGFloat = 28
    /// Fixed trailing slot for a selection checkmark. Keeping the slot
    /// present prevents an adjacent value from moving when selected.
    static let selectionIndicatorColumn: CGFloat = 28
    static let temperatureKelvinColumn: CGFloat = 72
    static let compactSnapshotSymbol: CGFloat = 32
}
