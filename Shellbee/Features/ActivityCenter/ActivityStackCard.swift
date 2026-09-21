import SwiftUI

/// A collapsed stack: the newest event on top with two slivers peeking out
/// underneath, like a Notification Center stack.
struct ActivityStackCard: View {
    let stack: ActivityStack
    let content: ActivityCardContent
    let store: AppStore?

    var body: some View {
        VStack(spacing: 0) {
            ActivityCard(entry: stack.latest, content: content, store: store, moreText: moreText)
                .zIndex(2)
            if stack.isStacked {
                peek(
                    height: DesignTokens.ActivityFeed.firstPeekHeight,
                    inset: DesignTokens.ActivityFeed.firstPeekInset,
                    opacity: DesignTokens.ActivityFeed.firstPeekOpacity
                )
                .zIndex(1)
                peek(
                    height: DesignTokens.ActivityFeed.secondPeekHeight,
                    inset: DesignTokens.ActivityFeed.secondPeekInset,
                    opacity: DesignTokens.ActivityFeed.secondPeekOpacity
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(stack.isStacked ? Text("Shows all events") : Text("Shows details"))
    }

    private var moreText: String? {
        guard stack.isStacked else { return nil }
        let remaining = stack.eventCount - stack.latest.coalescedCount
        let allUpdates = stack.entries.dropFirst().allSatisfy { $0.category == .stateChange }
        if allUpdates {
            return remaining == 1 ? String(localized: "1 more update") : String(localized: "\(remaining) more updates")
        }
        return remaining == 1 ? String(localized: "1 more event") : String(localized: "\(remaining) more events")
    }

    private func peek(height: CGFloat, inset: CGFloat, opacity: Double) -> some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: DesignTokens.ActivityFeed.peekCornerRadius,
            bottomTrailingRadius: DesignTokens.ActivityFeed.peekCornerRadius
        )
        .fill(Color(.secondarySystemGroupedBackground).opacity(opacity))
        .frame(height: height)
        .padding(.horizontal, inset)
    }
}
