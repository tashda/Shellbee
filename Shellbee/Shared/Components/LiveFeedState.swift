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

/// The compact toolbar action shown only after a live feed has been frozen.
struct FollowLiveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line.compact")
        }
        .accessibilityLabel("Follow Live")
        .accessibilityHint("Shows new activity and returns to the latest entry")
    }
}

enum LiveFeedAnchor {
    static let top = "live-feed-top"
}
