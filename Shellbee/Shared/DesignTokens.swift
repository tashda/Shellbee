import SwiftUI

nonisolated enum DesignTokens {
    nonisolated enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let summaryRowTextSpacing: CGFloat = 3
        static let summaryRowVerticalPadding: CGFloat = 2
    }

    nonisolated enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let summaryRowSymbolBackground: CGFloat = 10
        static let xl: CGFloat = 28
        static let noteBar: CGFloat = 1.5
    }

    nonisolated enum Size {
        static let statusDot: CGFloat = 10
        static let statusDotHero: CGFloat = 8
        static let statusDotInline: CGFloat = 6
        static let chipFont: CGFloat = 10
        static let chipSymbol: CGFloat = 9
        static let compactChipFont: CGFloat = 10
        static let compactChipSymbol: CGFloat = 10
        static let metaLabelFont: CGFloat = 12
        static let metaValueFont: CGFloat = 13
        static let lastSeenValueFont: CGFloat = 13
        static let hubSymbol: CGFloat = 20
        static let deviceUpgradeBadgeInset: CGFloat = 2
        static let deviceUpgradeBadgePadding: CGFloat = 1
        static let deviceUpgradeBadgeScale: CGFloat = 0.50
        static let deviceUpgradeIconScale: CGFloat = 0.16
        static let deviceUpgradeIconBackgroundScale: CGFloat = 0.7
        static let deviceUpgradeAvailableIconScale: CGFloat = 0.35
        static let deviceActionSheetImage: CGFloat = 52
        static let filterPopoverWidth: CGFloat = 320
        static let summaryRowSymbol: CGFloat = 18
        static let summaryRowSymbolFrame: CGFloat = 36
        static let summaryRowTrailingIcon: CGFloat = 20
        static let heroSymbol: CGFloat = 34
        static let metricSymbol: CGFloat = 18
        static let cardSymbol: CGFloat = 22
        static let toolbarSymbol: CGFloat = 18
        static let filterChipChevron: CGFloat = 8
        static let levelIndicatorWidth: CGFloat = 4
        static let levelIndicatorHeight: CGFloat = 20
        static let cardStroke: CGFloat = 1
        static let badgeStroke: CGFloat = 0.5
        static let hairline: CGFloat = 0.5
        static let notificationBottomInset: CGFloat = 80
        static let heroCardMinHeight: CGFloat = 200
        static let metricCardMinHeight: CGFloat = 120
        static let bridgeCardMinHeight: CGFloat = 164
        static let attentionCardMinHeight: CGFloat = 188
        static let hubItemMinHeight: CGFloat = 56
        static let dragHandleWidth: CGFloat = 36
        static let dragHandleHeight: CGFloat = 5
        static let deviceCardImage: CGFloat = 64
        static let deviceCardMetricDivider: CGFloat = 30
        static let deviceCardMetricIconHeight: CGFloat = 12
        static let deviceCardMetricValueHeight: CGFloat = 12
        static let deviceCardFooterMinSpacing: CGFloat = 12
        static let compactChipVerticalPadding: CGFloat = 2
        static let compactChipHorizontalPadding: CGFloat = 7
        static let footerTopRule: CGFloat = 1
        static let headerLastSeenWidth: CGFloat = 88
        static let deviceStatusPillPaddingH: CGFloat = 8
        static let deviceStatusPillPaddingV: CGFloat = 4
        static let deviceStatusLastSeenFont: CGFloat = 10
        static let settingsIconFrame: CGFloat = 28
        static let statusBadgeFont: CGFloat = 11
        static let colorSwatchSize: CGFloat = 12
        static let logLevelDotSize: CGFloat = 8
        static let logLevelIconWidth: CGFloat = 14
        static let logLevelDotTopPad: CGFloat = 6
        static let restartIconFrame: CGFloat = 40
        static let logRowDeviceImage: CGFloat = 34
        static let logFilterSearchRevealHeight: CGFloat = 54
        static let lightHeroPreview: CGFloat = 44
        static let lightColorPreview: CGFloat = 24
        static let lightColorSwatch: CGFloat = 24
        static let lightControlButton: CGFloat = 36
        static let lightPaletteSwatch: CGFloat = 28
        static let lightCustomPreview: CGFloat = 88
        static let docStepCircle: CGFloat = 28
        static let docStepConnector: CGFloat = 2
        static let docOptionPaddingV: CGFloat = 3
        static let docInfoIconFrame: CGFloat = 28
        static let docSectionIconFrame: CGFloat = 32
        static let docNoteBarWidth: CGFloat = 3
        static let chipVerticalPadding: CGFloat = 3
        static let splashIcon: CGFloat = 60
        static let splashTitle: CGFloat = 40
        static let touchlinkButtonFrame: CGFloat = 24
        static let climateActionButton: CGFloat = 32
        static let climateSetpointMinWidth: CGFloat = 72
    }

    nonisolated enum Shadow {
        static let badgeOpacity: Double = 0.12
        static let badgeRadius: CGFloat = 2
        static let badgeY: CGFloat = 1
        static let floatingOpacity: Double = 0.18
        static let floatingRadius: CGFloat = 6
        static let floatingY: CGFloat = 3
    }

    nonisolated enum Gradient {
        static let progress = [Color.blue, Color.blue.opacity(0.7)]
        static let updateAvailable = [Color.blue, Color(red: 0.2, green: 0.5, blue: 1.0)]
    }

    nonisolated enum Threshold {
        static let lowBattery = 20
        static let weakSignal = 40
    }

    nonisolated enum Duration {
        static let standardAnimation: Double = 0.3
        static let hubAnimation: Double = 0.36
        static let liveActivitySuccess: Double = 3
        static let liveActivityFailure: Double = 8
        static let liveActivityMinimumVisible: Double = 2
        static let liveActivityCancel: Double = 0.5
        static let statusPulse: Double = 1.8
        static let otaBadgeSpin: Double = 1.1
        static let pressedState: Double = 0.16
    }

    nonisolated enum Typography {
        static let cardHeadline: Font = .title3.weight(.semibold)
        static let cardSubheadline: Font = .subheadline
    }

    nonisolated enum Opacity {
        static let overlay: Double = 0.3
        static let secondaryText: Double = 0.8
        static let chipFill: Double = 0.12
        static let subtleFill: Double = 0.12
        static let softFill: Double = 0.18
        static let accentFill: Double = 0.2
        static let cardStroke: Double = 0.18
        static let glow: Double = 0.16
    }

}
