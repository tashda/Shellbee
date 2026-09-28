import SwiftUI

/// A full-screen stage for judging an instrument where people actually see
/// it: the Activity feed, Home's Recent Events, and the tab bar accessory
/// both expanded and minimized. Every surface renders the shipping views.
@available(iOS 26.0, *)
struct ActivityInstrumentStageView: View {
    let samples: [ActivityInstrumentGallerySample]
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var surface: Surface = .activity
    @State private var appearance: ColorScheme = .light

    init(samples: [ActivityInstrumentGallerySample], startIndex: Int) {
        self.samples = samples
        _index = State(initialValue: startIndex)
    }

    enum Surface: String, CaseIterable, Identifiable {
        case activity = "Activity Center"
        case home = "Recent Events"
        case tabBar = "Tab Bar"
        case minimized = "Minimized Tab Bar"
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .activity: return "rectangle.stack.fill"
            case .home: return "house.fill"
            case .tabBar: return "dock.rectangle"
            case .minimized: return "capsule.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            LiveActivityPalette.stageBackdrop.ignoresSafeArea()
            InstrumentStageDevice(appearance: appearance) {
                InstrumentStageScreen(surface: surface, items: window, current: currentSample)
            }
            .padding(.top, DesignTokens.Size.liveActivityStageDeviceTop)
            .padding(.bottom, DesignTokens.Size.liveActivityStageDeviceBottom)
            .animation(.snappy, value: surface)
        }
        .overlay(alignment: .bottom) {
            ActivityInstrumentStageControls(
                samples: samples,
                index: $index,
                surface: $surface,
                appearance: $appearance
            )
        }
        .overlay(alignment: .topLeading) {
            LiveActivityStageCloseButton { dismiss() }
                .padding(.leading, DesignTokens.Spacing.lg)
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private var currentSample: ActivityInstrumentGallerySample {
        samples[min(index, samples.count - 1)]
    }

    /// The current sample first, then its neighbours, so the instrument is
    /// judged among the ones it will sit next to in a real feed.
    private var window: [ActivityEventItem] {
        let count = DesignTokens.ActivityInstrument.stageNeighbours + 1
        return (0..<count).compactMap { offset in
            let position = index + offset
            guard samples.indices.contains(position) else { return nil }
            let sample = samples[position]
            return ActivityEventItem(
                instrument: sample.instrument,
                content: ActivityCardContent(title: sample.title, message: sample.detail),
                timestamp: .now.addingTimeInterval(-Double(offset) * 90)
            )
        }
    }
}

/// A phone-sized screen laid out at true iPhone scale, then scaled to fit
/// the stage, the same way the Live Activity stage frames its screens.
@available(iOS 26.0, *)
private struct InstrumentStageDevice<Screen: View>: View {
    let appearance: ColorScheme
    @ViewBuilder let screen: () -> Screen

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(
                width: DesignTokens.Size.liveActivityStageScreenWidth,
                height: DesignTokens.Size.liveActivityStageScreenHeight
            )
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            let shape = RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.liveActivityStageScreen, style: .continuous)
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                screen()
                InstrumentStageStatusBar()
            }
            .environment(\.colorScheme, appearance)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.black, lineWidth: DesignTokens.Size.liveActivityStageBezel))
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

@available(iOS 26.0, *)
private struct InstrumentStageStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41")
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: DesignTokens.Size.liveActivityStageStatusBarGap)
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .frame(maxWidth: .infinity)
        }
        .font(.body.weight(.semibold))
        .frame(height: DesignTokens.Size.liveActivityGalleryIslandHeight)
        .padding(.top, DesignTokens.Size.liveActivityStageIslandTop)
        .overlay {
            Capsule()
                .fill(.black)
                .frame(width: DesignTokens.Size.liveActivityStageStatusBarGap, height: DesignTokens.Size.liveActivityGalleryIslandHeight)
                .padding(.top, DesignTokens.Size.liveActivityStageIslandTop)
        }
    }
}
