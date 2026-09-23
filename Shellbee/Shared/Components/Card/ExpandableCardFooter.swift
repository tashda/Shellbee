import SwiftUI

/// A consistent reveal affordance for ranked data inside dashboard cards.
struct ExpandableCardFooter: View {
    @Binding var isExpanded: Bool
    let remainingCount: Int
    let itemName: String

    var body: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(isExpanded ? "Show less" : "Show all \(itemName)")
                if !isExpanded {
                    Text("\(remainingCount) more")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .font(.footnote.weight(.semibold))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Show fewer \(itemName)" : "Show all \(itemName)")
    }
}

struct ExpandableCardFade: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, Color(.secondarySystemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: DesignTokens.Size.expandableCardFade)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
