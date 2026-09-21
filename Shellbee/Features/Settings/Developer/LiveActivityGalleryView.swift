import SwiftUI

/// Every Live Activity state, drawn with the same views the widget uses, at
/// the system's own sizes. The minimal presentation is left out: its
/// countdown ring only renders properly inside a real Live Activity. The real Lock Screen and Dynamic Island only show
/// an activity while the app is in the background, so this is the reliable
/// way to review each moment side by side.
struct LiveActivityGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                ForEach(PermitJoinGallerySample.all) { sample in
                    GallerySection(title: sample.name, layout: sample.layout)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .navigationTitle("Live Activity Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GallerySection: View {
    let title: String
    let layout: LiveActivityLayout

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            GalleryCompactIsland(layout: layout)
            GalleryExpandedIsland(layout: layout)
            GalleryLockScreen(layout: layout)
        }
    }
}

// MARK: - Presentations

private enum GalleryMetrics {
    static let width = DesignTokens.Size.liveActivityGalleryWidth
    static let islandHeight = DesignTokens.Size.liveActivityGalleryIslandHeight
    static let camera = DesignTokens.Size.liveActivityGalleryCamera
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
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .frame(maxWidth: .infinity)
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
        .background(.black, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.liveActivityGalleryIsland, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.liveActivityGalleryIsland, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .frame(maxWidth: .infinity)
    }
}

private struct GalleryLockScreen: View {
    let layout: LiveActivityLayout

    var body: some View {
        LiveActivityLockScreen(layout: layout)
            .frame(width: GalleryMetrics.width)
            .background(Color(white: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Samples

private struct PermitJoinGallerySample: Identifiable {
    let name: String
    let layout: LiveActivityLayout
    var id: String { name }

    static var all: [Self] {
        let start = Date.now.addingTimeInterval(-30)
        let end = start.addingTimeInterval(254)
        let attributes = PermitJoinActivityAttributes(identifier: "gallery", bridgeDisplayName: "")
        let multiBridge = PermitJoinActivityAttributes(identifier: "gallery", bridgeDisplayName: "Upstairs Bridge")
        func state(joined: Int = 0, interviewing: [String] = [], failure: String? = nil, paired: String? = nil, ended: Bool = false) -> PermitJoinActivityAttributes.ContentState {
            .init(joinedCount: joined, startedAt: start, endsAt: ended ? .now.addingTimeInterval(-1) : end, targetName: nil,
                  interviewing: interviewing, interviewFailure: failure, recentlyPaired: paired)
        }
        func sample(_ name: String, _ state: PermitJoinActivityAttributes.ContentState, _ attributes: PermitJoinActivityAttributes = attributes) -> Self {
            Self(name: name, layout: .permitJoin(attributes: attributes, state: state, isStale: false))
        }
        return [
            sample("Waiting", state()),
            sample("Interviewing", state(interviewing: ["Hallway Motion Sensor"])),
            sample("Paired", state(joined: 1, paired: "Hallway Motion Sensor")),
            sample("Interview failed", state(joined: 1, failure: "Kitchen Plug")),
            sample("Joined, several bridges", state(joined: 3), multiBridge),
            sample("Closed", state(joined: 3, ended: true))
        ]
    }
}
