import SwiftUI

/// The stage's floating control panel: a state row you can step through, and
/// a row for surface, design and wallpaper. Sized to fit the narrowest
/// iPhone, so nothing ever runs off the screen.
@available(iOS 26.0, *)
struct LiveActivityStageControls: View {
    let samples: [LiveActivityGallerySample]
    @Binding var sampleIndex: Int
    let styles: [LiveActivityStyle]
    /// The style the widget ships with, labelled so it's never in doubt.
    let currentStyle: LiveActivityStyle
    @Binding var style: LiveActivityStyle
    @Binding var surface: LiveActivityStageView.Surface
    @Binding var wallpaper: LiveActivityStageWallpaper

    var body: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.sm) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                StateNavigator(samples: samples, sampleIndex: $sampleIndex)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    SurfaceSwitch(surface: $surface)
                    StyleMenu(styles: styles, currentStyle: currentStyle, style: $style)
                    WallpaperMenu(wallpaper: $wallpaper)
                }
            }
        }
        .tint(.white)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }
}

/// Round glass close button for the stage's top-left corner.
@available(iOS 26.0, *)
struct LiveActivityStageCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: StageControlMetrics.height, height: StageControlMetrics.height)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Close")
    }
}

// MARK: - Rows

@available(iOS 26.0, *)
private struct StateNavigator: View {
    let samples: [LiveActivityGallerySample]
    @Binding var sampleIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            step("chevron.left", label: "Previous state", by: -1)
            Menu {
                Picker("State", selection: $sampleIndex) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                        Text(sample.name).tag(index)
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(samples[safe: sampleIndex]?.name ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("State \(sampleIndex + 1) of \(samples.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.white)
            step("chevron.right", label: "Next state", by: 1)
        }
        .frame(height: StageControlMetrics.height)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: sampleIndex)
    }

    private func step(_ symbol: String, label: String, by offset: Int) -> some View {
        let target = sampleIndex + offset
        let enabled = samples.indices.contains(target)
        return Button {
            withAnimation(.snappy) { sampleIndex = target }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: StageControlMetrics.height, height: StageControlMetrics.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

@available(iOS 26.0, *)
private struct SurfaceSwitch: View {
    @Binding var surface: LiveActivityStageView.Surface

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LiveActivityStageView.Surface.allCases) { option in
                Button {
                    withAnimation(.snappy) { surface = option }
                } label: {
                    Image(systemName: option.symbol)
                        .font(.body.weight(.semibold))
                        .frame(width: StageControlMetrics.segment, height: StageControlMetrics.height)
                        .background {
                            if surface == option {
                                Capsule().fill(.white.opacity(0.22))
                                    .padding(DesignTokens.Spacing.xs)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(surface == option ? 1 : 0.6))
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(surface == option ? .isSelected : [])
            }
        }
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}

@available(iOS 26.0, *)
private struct StyleMenu: View {
    let styles: [LiveActivityStyle]
    let currentStyle: LiveActivityStyle
    @Binding var style: LiveActivityStyle

    var body: some View {
        Menu {
            Picker("Design", selection: $style) {
                ForEach(styles) { option in
                    Text(option == currentStyle ? "\(option.name) · Current" : option.name).tag(option)
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "paintpalette.fill")
                VStack(alignment: .leading, spacing: 0) {
                    Text(style.name)
                        .font(.subheadline.weight(.semibold))
                    Text(style == currentStyle ? "Current" : "Preview")
                        .font(.caption2)
                        .foregroundStyle(style == currentStyle ? LiveActivityPalette.success : .white.opacity(0.6))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: StageControlMetrics.height)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: Capsule())
        .accessibilityLabel("Design, \(style.name)")
    }
}

@available(iOS 26.0, *)
private struct WallpaperMenu: View {
    @Binding var wallpaper: LiveActivityStageWallpaper

    var body: some View {
        Menu {
            Picker("Wallpaper", selection: $wallpaper) {
                ForEach(LiveActivityStageWallpaper.allCases) { option in
                    Text(option.name).tag(option)
                }
            }
        } label: {
            Image(systemName: "photo.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: StageControlMetrics.height, height: StageControlMetrics.height)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("Wallpaper, \(wallpaper.name)")
    }
}

// MARK: - Support

private enum StageControlMetrics {
    static let height = DesignTokens.Size.liveActivityStageControl
    static let segment = DesignTokens.Size.liveActivityStageSegment
}

@available(iOS 26.0, *)
private extension LiveActivityStageView.Surface {
    var symbol: String {
        switch self {
        case .compact: return "capsule"
        case .expanded: return "rectangle.roundedtop"
        case .lock: return "lock.fill"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
