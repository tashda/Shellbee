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
        static let inspectorTabPickerWidth: CGFloat = 220
        static let inspectorPayloadInset: CGFloat = 10
        static let restoreStepCircle: CGFloat = 24
        static let splashIconLarge: CGFloat = 120
        static let mainTabBarInset: CGFloat = 58
        static let permitJoinQR: CGFloat = 220
        static let homeAddDividerInset: CGFloat = 60
        static let docLabelColumnWidth: CGFloat = 90
        static let permitJoinRingStroke: CGFloat = 8
        static let lightSelectionStroke: CGFloat = 2
        // Offsets (pixel-pushing for badge alignment over a parent shape)
        static let logRowBadgeOffset: CGFloat = 3
        static let firmwareUpdateBadgeOffsetX: CGFloat = 4
        static let firmwareUpdateBadgeOffsetY: CGFloat = -2
        static let homeCardSlotButtonOffset: CGFloat = -8
    }

    nonisolated enum Shadow {
        static let badgeOpacity: Double = 0.12
        static let badgeRadius: CGFloat = 2
        static let badgeY: CGFloat = 1
        static let floatingOpacity: Double = 0.18
        static let floatingRadius: CGFloat = 6
        static let floatingY: CGFloat = 3
        static let splashRadius: CGFloat = 18
        static let splashY: CGFloat = 8
    }

    nonisolated enum Tracking {
        static let splashTitle: CGFloat = -1
    }

    nonisolated enum Gradient {
        static let progress = [Color.blue, Color.blue.opacity(DesignTokens.Opacity.secondaryFull)]
        static let updateAvailable = [Color.blue, Color(red: 0.2, green: 0.5, blue: 1.0)]
    }

    nonisolated enum Bridge {
        static let palette: [Color] = [
            Color(red: 0.20, green: 0.56, blue: 0.87),
            Color(red: 0.93, green: 0.39, blue: 0.32),
            Color(red: 0.31, green: 0.69, blue: 0.31),
            Color(red: 0.95, green: 0.63, blue: 0.20),
            Color(red: 0.61, green: 0.36, blue: 0.85),
            Color(red: 0.20, green: 0.74, blue: 0.74),
            Color(red: 0.92, green: 0.46, blue: 0.65),
            Color(red: 0.40, green: 0.50, blue: 0.30),
        ]

        static let legacyIndexOverridesKey = "savedBridges.colorOverrides"
        private static let customColorsKey = "savedBridges.customColors"

        static func color(for bridgeID: UUID) -> Color {
            migrateLegacyOverrideIfNeeded(for: bridgeID)

            if let hex = customColorHex(for: bridgeID),
               let color = colorFromHex(hex) {
                return color
            }
            return palette[autoIndex(for: bridgeID)]
        }

        static func setCustomColor(_ color: Color?, for bridgeID: UUID) {
            var dict = customColorsMap()
            if let color, let hex = hexString(for: color) {
                dict[bridgeID.uuidString] = hex
            } else {
                dict.removeValue(forKey: bridgeID.uuidString)
            }
            saveCustomColorsMap(dict)
        }

        static func customColorHex(for bridgeID: UUID) -> String? {
            customColorsMap()[bridgeID.uuidString]
        }

        static func autoIndex(for bridgeID: UUID) -> Int {
            guard !palette.isEmpty else { return 0 }
            let bytes = withUnsafeBytes(of: bridgeID.uuid) { Array($0) }
            let sum = bytes.reduce(0) { $0 &+ Int($1) }
            return abs(sum) % palette.count
        }

        /// Picks a palette color that is not currently used by another saved
        /// bridge custom color when possible. Falls back to any palette color.
        static func suggestedAvailableColor() -> Color {
            let usedHex = Set(customColorsMap().values.map { $0.uppercased() })
            let available = palette.filter { color in
                guard let hex = hexString(for: color)?.uppercased() else { return true }
                return !usedHex.contains(hex)
            }
            let source = available.isEmpty ? palette : available
            guard !source.isEmpty else { return .accentColor }
            return source[Int.random(in: 0..<source.count)]
        }

        private static func migrateLegacyOverrideIfNeeded(for bridgeID: UUID) {
            if customColorHex(for: bridgeID) != nil { return }
            guard let data = UserDefaults.standard.data(forKey: legacyIndexOverridesKey),
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data),
                  let index = decoded[bridgeID.uuidString],
                  palette.indices.contains(index),
                  let hex = hexString(for: palette[index]) else { return }

            var dict = customColorsMap()
            dict[bridgeID.uuidString] = hex
            saveCustomColorsMap(dict)
        }

        private static func customColorsMap() -> [String: String] {
            guard let data = UserDefaults.standard.data(forKey: customColorsKey),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return decoded
        }

        private static func saveCustomColorsMap(_ map: [String: String]) {
            if map.isEmpty {
                UserDefaults.standard.removeObject(forKey: customColorsKey)
                return
            }
            if let data = try? JSONEncoder().encode(map) {
                UserDefaults.standard.set(data, forKey: customColorsKey)
            }
        }

        static func colorFromHex(_ hex: String) -> Color? {
            let start = hex.hasPrefix("#") ? hex.index(after: hex.startIndex) : hex.startIndex
            let value = String(hex[start...])
            guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
            let r = Double((number & 0xFF0000) >> 16) / 255.0
            let g = Double((number & 0x00FF00) >> 8) / 255.0
            let b = Double(number & 0x0000FF) / 255.0
            return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        }

        static func hexString(for color: Color) -> String? {
            #if canImport(UIKit)
            let components = UIColor(color).cgColor.components
            let resolved: [CGFloat]
            switch components?.count {
            case 2:
                resolved = [components?[0] ?? 0, components?[0] ?? 0, components?[0] ?? 0]
            case 4:
                resolved = [components?[0] ?? 0, components?[1] ?? 0, components?[2] ?? 0]
            default:
                return nil
            }
            let red = Int((resolved[0] * 255).rounded())
            let green = Int((resolved[1] * 255).rounded())
            let blue = Int((resolved[2] * 255).rounded())
            return String(format: "#%02X%02X%02X", red, green, blue)
            #else
            return nil
            #endif
        }
    }

    nonisolated enum Threshold {
        static let lowBattery = 20
        static let weakSignal = 40
    }

    /// Proportional layout ratios — multipliers applied to a parent dimension
    /// (e.g. an offset that's 28% of the parent frame side, a corner radius
    /// that's 27% of the tile size). Use these instead of inline percentages
    /// so the whole layout scales consistently.
    nonisolated enum Ratio {
        // Log row icon (device thumbnail badge inside the log level circle)
        static let logRowBadgeSize: CGFloat = 0.47
        static let logRowBadgeBorder: CGFloat = 0.1
        static let logRowBadgeBorderMin: CGFloat = 1.5

        // Group icon (member device images stacked into a group thumbnail)
        static let groupIconMember: CGFloat = 0.72
        static let groupIconOffset: CGFloat = 0.28
        static let groupIconCorner: CGFloat = 0.28

        // Device image (status / availability dot inside the thumbnail)
        static let deviceImageDot: CGFloat = 0.26
        static let deviceImageDotMin: CGFloat = 7

        // Feature tile (rounded rect background corner radius)
        static let featureTileCorner: CGFloat = 0.27

        // Member avatar stack (group detail row, etc)
        static let memberAvatarBorder: CGFloat = 0.063
        static let memberAvatarBorderMin: CGFloat = 1.5
        static let memberAvatarFont: CGFloat = 0.375
        static let memberAvatarBadgeFont: CGFloat = 0.44
        static let memberAvatarBadgeFontMin: CGFloat = 9
        static let memberAvatarBadgePadding: CGFloat = 0.25
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
        // Common SwiftUI .easeInOut / .snappy / withAnimation durations
        static let quickFade: Double = 0.15
        static let fastFade: Double = 0.2
        static let mediumAnimation: Double = 0.25
        static let slowAnimation: Double = 0.6
        static let pulseExpand: Double = 0.8
        static let pulseFull: Double = 1.0
        static let checkResultDisplay: Double = 3
        static let pendingDeleteTimeout: Double = 15
        static let discoveryScanWindow: Double = 15
    }

    nonisolated enum Typography {
        static let cardHeadline: Font = .title3.weight(.semibold)
        static let cardSubheadline: Font = .subheadline

        // MARK: Eyebrow pattern (small uppercase label above metric values)
        // Used as the small contextual label at the top of every card.
        // (#36.A resolved 2026-04-29: unified all card eyebrows on 11pt.)
        static let eyebrowLabel: Font = .system(size: 11, weight: .semibold)
        static let eyebrowIcon: Font = .system(size: 11, weight: .bold)
        static let eyebrowTracking: CGFloat = 0.5

        // MARK: Section header (uppercase label dividing content within a card)
        // Slightly larger and looser-tracked than card eyebrows. One step up
        // in the visual hierarchy.
        static let sectionHeaderLabel: Font = .system(size: 12, weight: .semibold)
        static let sectionHeaderIcon: Font = .system(size: 12, weight: .bold)
        static let sectionHeaderTracking: CGFloat = 0.6

        // MARK: Hero metric (the giant number/state on a card hero block)
        static let heroValue: Font = .system(size: 56, weight: .bold, design: .rounded)
        // Used for "On"/"Off"/"Unlocked"/"Closed" hero text when there's no
        // numeric metric. Slightly smaller than heroValue (deliberate — see #36).
        static let heroStateText: Font = .system(size: 48, weight: .bold, design: .rounded)
        // Unit text rendered next to heroValue (e.g. the "%" after a brightness)
        static let heroUnit: Font = .system(size: 18, weight: .medium, design: .rounded)
        // Smaller subtitle text under the hero value (e.g. "Target 21.5°" under temperature)
        static let heroSubtitle: Font = .system(size: 20, weight: .semibold, design: .rounded)

        // MARK: Feature tile (1–N prominent stats in a card body, room to breathe)
        // Used by FanControlCard, RemoteCard, SensorCard, SwitchControlCard.
        static let featureTileValue: Font = .system(size: 30, weight: .semibold, design: .rounded)
        static let featureTileUnit: Font = .system(size: 15, weight: .medium, design: .rounded)
        // Identity tile (smaller — packed 2x2 grids of summary stats).
        // Used by DeviceCard / GroupCard for Type/Status/Signal/Power tiles,
        // and by ClimateControlCard for the setpoint number between +/- buttons.
        // The size distinction from featureTile is deliberate (#36.B resolved
        // 2026-04-29: keep two tiers, identity grid stays compact).
        static let identityTileValue: Font = .system(size: 24, weight: .semibold, design: .rounded)
        static let identityTileUnit: Font = .system(size: 14, weight: .medium, design: .rounded)
        // Snapshot-row variant (Light card colorSnapshotRow, Cover tilt row)
        static let snapshotRowValue: Font = .system(size: 20, weight: .semibold, design: .rounded)
        static let snapshotRowUnit: Font = .system(size: 13, weight: .medium, design: .rounded)

        // MARK: Card titles & section labels
        static let cardTitle: Font = .system(size: 24, weight: .bold, design: .rounded)
        // Smaller card title for the GroupCard header
        static let compactCardTitle: Font = .system(size: 20, weight: .bold, design: .rounded)
        static let footerActionLabel: Font = .system(size: 13, weight: .semibold, design: .rounded)
        static let sectionHeader: Font = .system(size: 15, weight: .semibold)

        // MARK: Form / settings rows
        static let formRowIcon: Font = .system(size: 16, weight: .medium)
        static let formRowIconBold: Font = .system(size: 16, weight: .semibold)

        // MARK: Misc one-offs
        static let sliderEndLabel: Font = .system(size: 9, weight: .medium)
        static let permitJoinCountdown: Font = .system(size: 64, weight: .thin)
        static let permitJoinSymbol: Font = .system(size: 48)
        // Banner level glyph — shared by InAppNotificationBanner and
        // FastTrackBanner (#36.D resolved 2026-04-29: unified on 15pt).
        static let notificationLevelIcon: Font = .system(size: 15, weight: .semibold)
        // Climate setpoint +/- button glyph
        static let climateActionIcon: Font = .system(size: 14, weight: .bold)
        // Light card secondary glyphs (compass / palette icon overlays)
        static let lightSecondaryIcon: Font = .system(size: 14, weight: .semibold)

        // MARK: Icon glyph ratios (proportional sizing inside a parent frame)
        // e.g. an icon glyph that fills half its containing thumbnail circle.
        // Used as multipliers: `.font(.system(size: parent * iconRatioHalf))`.
        static let iconRatioSmall: CGFloat = 0.38
        static let iconRatioHalf: CGFloat = 0.5
        static let iconRatioMedium: CGFloat = 0.55

        // MARK: minimumScaleFactor presets (per Text element shrink budgets)
        static let scaleFactorAggressive: CGFloat = 0.45
        static let scaleFactorTight: CGFloat = 0.55
        static let scaleFactorMedium: CGFloat = 0.6
        static let scaleFactorRelaxed: CGFloat = 0.7
        static let scaleFactorMild: CGFloat = 0.75
        static let scaleFactorSubtle: CGFloat = 0.82
        static let scaleFactorAggressiveLight: CGFloat = 0.65
        static let scaleFactorMildLight: CGFloat = 0.72
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
        // The thin divider rule color tint used across cards
        static let hairline: Double = 0.08
        // Subtle gradient fade, off-state hue tint
        static let subtleFade: Double = 0.04
        // Off-state hero tint, "tertiaryLabel" gradient
        static let offStateTint: Double = 0.06
        static let onStateTint: Double = 0.18
        // Climate action button background, color preview overlays
        static let actionButtonFill: Double = 0.15
        static let strongAccentFill: Double = 0.20
        static let mediumAccentFill: Double = 0.14
        // Notification background blur
        static let banner: Double = 0.9
        // Unique one-offs
        static let veryFaint: Double = 0.03
        static let veryLight: Double = 0.05
        static let lightOpaque: Double = 0.10
        static let mildOpaque: Double = 0.22
        static let pressedAlpha: Double = 0.25
        static let dimmedSurface: Double = 0.30
        static let outOfRange: Double = 0.35
        static let secondaryDim: Double = 0.75
        static let secondaryFull: Double = 0.7
    }

}
