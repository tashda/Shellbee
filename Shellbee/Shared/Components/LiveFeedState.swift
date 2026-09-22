import Observation
import SwiftUI

/// Keeps a live feed stable once the user starts reading older content.
///
/// A feed supplies its current snapshot on every render. The first deliberate
/// drag freezes that snapshot, so entries arriving at the live edge cannot
/// move what the user is reading. `followLive()` resumes normal updates.
@MainActor
@Observable
final class LiveFeedState<Item: Identifiable> where Item.ID: Hashable {
    private(set) var frozenItems: [Item]?

    var isReadingHistory: Bool { frozenItems != nil }

    func displayedItems(from liveItems: [Item]) -> [Item] {
        frozenItems ?? liveItems
    }

    func beginReadingHistory(with liveItems: [Item]) {
        guard frozenItems == nil else { return }
        frozenItems = liveItems
    }

    func followLive() {
        frozenItems = nil
    }
}

/// Freezes the feed once the user has scrolled away from the live edge and
/// resumes it when they scroll back. A feed too short to scroll never
/// freezes, so it never offers Follow Live.
struct LiveFeedScrollTracking<Item: Identifiable>: ViewModifier where Item.ID: Hashable {
    let state: LiveFeedState<Item>
    let liveItems: [Item]

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > DesignTokens.ActivityFeed.liveEdgeTolerance
            } action: { _, isAwayFromLiveEdge in
                if isAwayFromLiveEdge {
                    state.beginReadingHistory(with: liveItems)
                } else {
                    state.followLive()
                }
            }
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: DesignTokens.Spacing.xs).onChanged { _ in
                state.beginReadingHistory(with: liveItems)
            })
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
            Image(systemName: "arrow.up.to.line")
        }
        .accessibilityLabel("Follow Live")
        .accessibilityHint("Shows new activity and returns to the latest entry")
    }
}

enum LiveFeedAnchor {
    static let top = "live-feed-top"
}
