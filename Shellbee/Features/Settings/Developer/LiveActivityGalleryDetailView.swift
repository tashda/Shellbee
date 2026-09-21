import SwiftUI

/// One activity, one state per page: swipe between states and see the
/// compact island, the expanded island and the Lock Screen together.
struct LiveActivityGalleryDetailView: View {
    let kind: LiveActivityGalleryKind
    @State private var anchor = Date.now
    @State private var selection = 0

    var body: some View {
        let samples = kind.samples(anchor: anchor)
        TabView(selection: $selection) {
            ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                GalleryStatePage(sample: sample)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(kind.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Countdowns would otherwise run out while the page stays open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityGalleryWindow))
                anchor = .now
            }
        }
    }
}

private struct GalleryStatePage: View {
    let sample: LiveActivityGallerySample

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                Text(sample.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                GalleryPresentation(title: "Compact") {
                    GalleryCompactIsland(layout: sample.layout)
                }
                GalleryPresentation(title: "Expanded") {
                    GalleryExpandedIsland(layout: sample.layout)
                }
                GalleryPresentation(title: "Lock Screen") {
                    GalleryLockScreen(layout: sample.layout)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xxl * 2)
        }
    }
}

private struct GalleryPresentation<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }
}

// MARK: - Presentations

private enum GalleryMetrics {
    static let width = DesignTokens.Size.liveActivityGalleryWidth
    static let islandHeight = DesignTokens.Size.liveActivityGalleryIslandHeight
    static let camera = DesignTokens.Size.liveActivityGalleryCamera
    static let islandRadius = DesignTokens.CornerRadius.liveActivityGalleryIsland
}

private struct GalleryCompactIsland: View {
    let layout: LiveActivityLayout

    var body: some View {
        HStack(spacing: 0) {
            LiveActivityCompactLeading(layout: layout)
            Color.clear.frame(width: GalleryMetrics.camera)
            LiveActivityCompactTrailing(layout: layout)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: GalleryMetrics.islandHeight)
        .background(.black, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
    }
}

private struct GalleryExpandedIsland: View {
    let layout: LiveActivityLayout

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                LiveActivityIslandLeading(layout: layout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: GalleryMetrics.camera, height: GalleryMetrics.islandHeight)
                LiveActivityIslandTrailing(layout: layout)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .fixedSize(horizontal: false, vertical: true)
            LiveActivityIslandBottom(layout: layout)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: GalleryMetrics.width)
        .background(.black, in: RoundedRectangle(cornerRadius: GalleryMetrics.islandRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: GalleryMetrics.islandRadius, style: .continuous).strokeBorder(.white.opacity(0.15)))
    }
}

private struct GalleryLockScreen: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityLockScreen(layout: layout)
            .frame(width: GalleryMetrics.width)
            .background(Color(white: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }
}
