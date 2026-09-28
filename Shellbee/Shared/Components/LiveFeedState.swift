import Observation
import SwiftUI

/// Value-only feed state so snapshot behavior can be tested without creating
/// an observable main-actor object inside XCTest.
nonisolated struct LiveFeedSnapshotState<Item: Identifiable> where Item.ID: Hashable {
    private(set) var frozenItems: [Item]?

    var isReadingHistory: Bool { frozenItems != nil }

    func displayedItems(from liveItems: [Item]) -> [Item] {
        frozenItems ?? liveItems
    }

    mutating func beginReadingHistory(with liveItems: [Item]) {
        guard frozenItems == nil else { return }
        frozenItems = liveItems
    }

    mutating func followLive() {
        frozenItems = nil
    }
}

/// Keeps a live feed stable once the user starts reading older content.
///
/// A feed supplies its current snapshot on every render. The first deliberate
/// drag freezes that snapshot, so entries arriving at the live edge cannot
/// move what the user is reading. `followLive()` resumes normal updates.
@MainActor
@Observable
final class LiveFeedState<Item: Identifiable> where Item.ID: Hashable {
    private var snapshot = LiveFeedSnapshotState<Item>()
    var frozenItems: [Item]? { snapshot.frozenItems }
    /// Bumped by Follow Live. The feed's scroll tracking watches it and
    /// scrolls to the newest entry.
    private(set) var returnToLiveRequest = 0

    var isReadingHistory: Bool { snapshot.isReadingHistory }

    func displayedItems(from liveItems: [Item]) -> [Item] {
        snapshot.displayedItems(from: liveItems)
    }

    func beginReadingHistory(with liveItems: [Item]) {
        snapshot.beginReadingHistory(with: liveItems)
    }

    func followLive() {
        snapshot.followLive()
    }

    /// Hides Follow Live straight away and asks the feed to scroll to the
    /// newest entry, so the button melts back into the search field as the
    /// scroll starts instead of once it has finished.
    func requestReturnToLive() {
        withAnimation(.smooth) { followLive() }
        returnToLiveRequest += 1
    }
}

/// Freezes the feed once the user has scrolled away from the live edge,
/// resumes it when they scroll back, and performs Follow Live's scroll to
/// the newest entry. A feed too short to scroll never freezes, so it never
/// offers Follow Live.
struct LiveFeedScrollTracking<Item: Identifiable>: ViewModifier where Item.ID: Hashable {
    let state: LiveFeedState<Item>
    let liveItems: [Item]

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(LiveFeedScrollPositionTracking(state: state, liveItems: liveItems))
        } else {
            ScrollViewReader { proxy in
                content
                    .simultaneousGesture(DragGesture(minimumDistance: DesignTokens.Spacing.xs).onChanged { _ in
                        state.beginReadingHistory(with: liveItems)
                    })
                    .onChange(of: state.returnToLiveRequest) {
                        Task { @MainActor in
                            withAnimation(.smooth) {
                                proxy.scrollTo(LiveFeedAnchor.top, anchor: .top)
                            }
                        }
                    }
            }
        }
    }
}

/// iOS 18+ tracking, driven by the scroll view's own geometry and position.
@available(iOS 18.0, *)
private struct LiveFeedScrollPositionTracking<Item: Identifiable>: ViewModifier where Item.ID: Hashable {
    let state: LiveFeedState<Item>
    let liveItems: [Item]
    @State private var position = ScrollPosition(edge: .top)
    @State private var offset: CGFloat = 0
    @State private var isAwayFromLiveEdge = false

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                offset = newOffset
                // Act only when the feed crosses the live edge, so the
                // scroll back up from Follow Live doesn't freeze it again.
                let isAway = newOffset > DesignTokens.ActivityFeed.liveEdgeTolerance
                guard isAway != isAwayFromLiveEdge else { return }
                isAwayFromLiveEdge = isAway
                // Animated so Follow Live floats out of the search field.
                withAnimation(.smooth) {
                    if isAway {
                        state.beginReadingHistory(with: liveItems)
                    } else {
                        state.followLive()
                    }
                }
            }
            .onChange(of: state.returnToLiveRequest) {
                // A flick may still be coasting. Its deceleration and an
                // animated scroll would fight over the offset, and the
                // coasting wins, so first pin the feed where it is, which
                // stops the momentum, then animate to the top.
                position.scrollTo(y: offset)
                Task { @MainActor in
                    withAnimation(.smooth) {
                        position.scrollTo(edge: .top)
                    }
                }
            }
    }
}

/// Follow Live, shown only while a feed is frozen. On iPhone with iOS 26+
/// it sits beside the search field in the bottom bar, like Mail's compose
/// button; elsewhere it is its own capsule in the top bar.
struct FollowLiveToolbarContent: ToolbarContent {
    let isVisible: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *), !AdaptiveLayout.isPad {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            if isVisible {
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    FollowLiveButton(action: action)
                }
            }
        } else if isVisible {
            TrailingToolbarGroupSpacer()
            ToolbarItem(placement: .topBarTrailing) {
                FollowLiveButton(action: action)
            }
        }
    }
}

/// Returns a frozen feed to the newest entry, which is at the top.
struct FollowLiveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ShellbeeSymbol.followLive.image
        }
        .accessibilityLabel("Follow Live")
        .accessibilityHint("Shows new activity and returns to the latest entry")
    }
}

enum LiveFeedAnchor {
    static let top = "live-feed-top"
}
