import SwiftUI

/// A full-screen stand-in for the Home Screen and Lock Screen, with the
/// activity drawn where the system draws it: the island over the hardware
/// Dynamic Island, the card above the Lock Screen's quick actions.
@available(iOS 26.0, *)
struct LiveActivityStageView: View {
    let kind: LiveActivityGalleryKind
    /// Set when the stage isn't presented by SwiftUI (the debug launch hook).
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var anchor = Date.now
    @State private var sampleIndex: Int
    @State private var surface: Surface
    @State private var style: LiveActivityStyle
    @State private var wallpaper = LiveActivityStageWallpaper.sand

    init(
        kind: LiveActivityGalleryKind,
        onClose: (() -> Void)? = nil,
        sampleIndex: Int = 0,
        surface: Surface = .compact,
        style: LiveActivityStyle? = nil
    ) {
        self.kind = kind
        self.onClose = onClose
        _sampleIndex = State(initialValue: sampleIndex)
        _surface = State(initialValue: surface)
        _style = State(initialValue: style ?? kind.defaultStyle)
    }

    enum Surface: String, CaseIterable, Identifiable {
        // Raw values double as picker titles and debug launch arguments.
        case compact = "Compact"
        case expanded = "Expanded"
        case lock = "Lock"
        var id: String { rawValue }
    }

    var body: some View {
        let samples = kind.samples(anchor: anchor)
        let sample = samples[min(sampleIndex, samples.count - 1)]
        let layout = sample.layout.styled(style)
        ZStack {
            // The wallpaper belongs to the screen being previewed: full-screen
            // for the Lock Screen, only inside the miniature phone otherwise.
            if surface == .lock {
                wallpaper.view.ignoresSafeArea()
            } else {
                LiveActivityPalette.stageBackdrop.ignoresSafeArea()
            }
            switch surface {
            case .compact, .expanded:
                StageDevice(wallpaper: wallpaper, showsStatusBar: surface == .compact) {
                    StageHomeScreen(layout: layout, isExpanded: surface == .expanded)
                }
                .padding(.top, StageMetrics.deviceTop)
                .padding(.bottom, StageMetrics.deviceBottom)
                // The system redraws an activity on every update, which
                // restarts effects like the pulse; switching states does too.
                .id(sampleIndex)
            case .lock:
                StageLockScreen(layout: layout)
                    .id(sampleIndex)
            }
        }
        .overlay(alignment: .bottom) {
            StageControls(
                samples: samples,
                sampleIndex: $sampleIndex,
                styles: kind.styles,
                currentStyle: kind.defaultStyle,
                style: $style,
                surface: $surface,
                wallpaper: $wallpaper,
                onClose: { onClose?() ?? dismiss() }
            )
        }
        .environment(\.colorScheme, .dark)
        .environment(\.isLiveActivityStagePreview, true)
        .preferredColorScheme(.dark)
        .task {
            // Countdowns would otherwise run out while the stage stays open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityGalleryWindow))
                anchor = .now
            }
        }
    }
}

// MARK: - Surfaces

@available(iOS 26.0, *)
private struct StageHomeScreen: View {
    let layout: LiveActivityLayout
    let isExpanded: Bool

    var body: some View {
        // The expanded island floats over the Home Screen, as on the device.
        ZStack(alignment: .top) {
            StageIconGrid()
                .padding(.top, StageMetrics.iconsTop)
            StageIsland(layout: layout, isExpanded: isExpanded)
                .animation(.spring(duration: 0.45, bounce: 0.25), value: isExpanded)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A miniature phone for the Home Screen surfaces. The real Dynamic Island
/// would sit on top of anything drawn in its place, so the mock screen is
/// laid out at full iPhone size, with its own status bar and island, then
/// scaled down to fit below it. Proportions stay true to the device.
@available(iOS 26.0, *)
private struct StageDevice<Screen: View>: View {
    let wallpaper: LiveActivityStageWallpaper
    /// iOS hides the status bar while the island is expanded.
    let showsStatusBar: Bool
    @ViewBuilder let screen: () -> Screen

    var body: some View {
        GeometryReader { proxy in
            let size = StageMetrics.screenSize
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            ZStack(alignment: .top) {
                wallpaper.view
                screen()
                if showsStatusBar {
                    StageStatusBar()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: StageMetrics.screenRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StageMetrics.screenRadius, style: .continuous)
                    .strokeBorder(.black, lineWidth: StageMetrics.bezel)
            )
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// Time on the left of the island, connectivity on the right, as on iPhone.
@available(iOS 26.0, *)
private struct StageStatusBar: View {
    var body: some View {
        HStack {
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
            }
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: StageMetrics.statusBarGap)
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .frame(maxWidth: .infinity)
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(height: StageMetrics.islandHeight)
        .padding(.top, StageMetrics.islandTop)
    }
}

/// The island at the mock screen's top, where the hardware island sits.
@available(iOS 26.0, *)
private struct StageIsland: View {
    let layout: LiveActivityLayout
    let isExpanded: Bool

    var body: some View {
        SwiftUI.Group {
            if isExpanded {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        LiveActivityIslandLeading(layout: layout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(width: StageMetrics.camera, height: StageMetrics.islandHeight)
                        LiveActivityIslandTrailing(layout: layout)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    LiveActivityIslandBottom(layout: layout)
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(width: StageMetrics.expandedWidth)
                .background(.black, in: RoundedRectangle(cornerRadius: StageMetrics.expandedRadius, style: .continuous))
            } else {
                HStack(spacing: 0) {
                    LiveActivityCompactLeading(layout: layout)
                    Color.clear.frame(width: StageMetrics.camera)
                    LiveActivityCompactTrailing(layout: layout)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .frame(height: StageMetrics.islandHeight)
                .background(.black, in: Capsule())
            }
        }
        .padding(.top, StageMetrics.islandTop)
    }
}

/// Placeholder icons give the island something to sit against, as on the
/// real Home Screen.
@available(iOS 26.0, *)
private struct StageIconGrid: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DesignTokens.Spacing.xl) {
            ForEach(0..<16, id: \.self) { _ in
                RoundedRectangle(cornerRadius: StageMetrics.iconRadius, style: .continuous)
                    .fill(.white.opacity(0.28))
                    .frame(width: StageMetrics.icon, height: StageMetrics.icon)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }
}

@available(iOS 26.0, *)
private struct StageLockScreen: View {
    let layout: LiveActivityLayout

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 0) {
                    Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.title3.weight(.semibold))
                        .padding(.top, StageMetrics.lockDateTop)
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(DesignTokens.Typography.liveActivityStageClock)
                }
            }
            Spacer()
            LiveActivityLockScreen(layout: layout)
                .frame(width: StageMetrics.expandedWidth)
                .clipShape(RoundedRectangle(cornerRadius: StageMetrics.cardRadius, style: .continuous))
                .padding(.bottom, StageMetrics.lockCardBottom)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Controls

@available(iOS 26.0, *)
private struct StageControls: View {
    let samples: [LiveActivityGallerySample]
    @Binding var sampleIndex: Int
    let styles: [LiveActivityStyle]
    /// The style the widget ships with, labelled so it's never in doubt.
    let currentStyle: LiveActivityStyle
    @Binding var style: LiveActivityStyle
    @Binding var surface: LiveActivityStageView.Surface
    @Binding var wallpaper: LiveActivityStageWallpaper
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: StageMetrics.control, height: StageMetrics.control)
            }
            .accessibilityLabel("Close")

            Picker("State", selection: $sampleIndex) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    Text(sample.name).tag(index)
                }
            }

            Picker("Style", selection: $style) {
                ForEach(styles) { style in
                    Text(style == currentStyle ? "\(style.name) · Current" : style.name).tag(style)
                }
            }

            Picker("Surface", selection: $surface) {
                ForEach(LiveActivityStageView.Surface.allCases) { surface in
                    Text(surface.rawValue).tag(surface)
                }
            }

            Menu {
                ForEach(LiveActivityStageWallpaper.allCases) { option in
                    Button {
                        wallpaper = option
                    } label: {
                        if option == wallpaper {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                }
            } label: {
                Image(systemName: "photo")
                    .frame(width: StageMetrics.control, height: StageMetrics.control)
            }
            .accessibilityLabel("Wallpaper")
        }
        .pickerStyle(.menu)
        .lineLimit(1)
        .fixedSize()
        .tint(.white)
        .padding(DesignTokens.Spacing.xs)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, DesignTokens.Spacing.sm)
    }
}

@available(iOS 26.0, *)
private enum StageMetrics {
    static let islandTop = DesignTokens.Size.liveActivityStageIslandTop
    static let screenSize = CGSize(width: DesignTokens.Size.liveActivityStageScreenWidth, height: DesignTokens.Size.liveActivityStageScreenHeight)
    static let screenRadius = DesignTokens.CornerRadius.liveActivityStageScreen
    static let bezel = DesignTokens.Size.liveActivityStageBezel
    static let statusBarGap = DesignTokens.Size.liveActivityStageStatusBarGap
    static let deviceTop = DesignTokens.Size.liveActivityStageDeviceTop
    static let deviceBottom = DesignTokens.Size.liveActivityStageDeviceBottom
    static let islandHeight = DesignTokens.Size.liveActivityGalleryIslandHeight
    static let camera = DesignTokens.Size.liveActivityGalleryCamera
    static let expandedWidth = DesignTokens.Size.liveActivityGalleryWidth
    static let expandedRadius = DesignTokens.CornerRadius.liveActivityGalleryIsland
    static let cardRadius = DesignTokens.CornerRadius.liveActivityStageCard
    static let icon = DesignTokens.Size.liveActivityStageIcon
    static let iconsTop = DesignTokens.Size.liveActivityStageIconsTop
    static let iconRadius = DesignTokens.CornerRadius.liveActivityStageIcon
    static let lockDateTop = DesignTokens.Size.liveActivityStageLockDateTop
    static let lockCardBottom = DesignTokens.Size.liveActivityStageLockCardBottom
    static let control = DesignTokens.Size.liveActivityStageControl
}
