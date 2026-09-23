import SwiftUI

@MainActor
private enum CardExpansion {
    static func toggle(_ expanded: Binding<Bool>) {
        var transaction = Transaction(animation: nil)
        if #available(iOS 18.0, *) {
            transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        }
        withTransaction(transaction) {
            expanded.wrappedValue.toggle()
        }
    }
}

/// The header and the fading final row share one expansion behavior.
struct ExpandableCardHeader<Content: View>: View {
    @Binding var isExpanded: Bool
    let hasMore: Bool
    let itemName: String
    let content: Content

    init(
        isExpanded: Binding<Bool>,
        hasMore: Bool,
        itemName: String,
        @ViewBuilder content: () -> Content
    ) {
        _isExpanded = isExpanded
        self.hasMore = hasMore
        self.itemName = itemName
        self.content = content()
    }

    var body: some View {
        Button {
            CardExpansion.toggle($isExpanded)
        } label: {
            content
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasMore)
        .accessibilityIdentifier("card-expand-header-\(itemName)")
        .accessibilityHint(hasMore
            ? (isExpanded ? "Shows fewer \(itemName)" : "Shows all \(itemName)")
            : "")
    }
}

/// Keeps a card's first rows fixed while a bounded viewport reveals the rest.
/// Only the extra rows' viewport animates, keeping the List row anchored.
struct ExpandableCardRows<Item: Identifiable, Row: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isExpanded: Bool
    let items: [Item]
    let itemName: String
    let previewCount: Int
    let rowHeight: CGFloat
    let spacing: CGFloat
    @ViewBuilder let row: (Item, Int) -> Row

    private var extra: [Item] { Array(items.dropFirst(previewCount)) }
    private var finalPreviewIndex: Int { min(items.count, previewCount) - 1 }

    private var expandedHeight: CGFloat {
        min(
            CGFloat(extra.count) * rowHeight
                + CGFloat(max(extra.count - 1, 0)) * spacing
                + spacing,
            DesignTokens.Size.cardExpandedMaxHeight
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: spacing) {
                ForEach(Array(items.prefix(previewCount).enumerated()), id: \.element.id) { index, item in
                    if !extra.isEmpty && index == finalPreviewIndex {
                        Button {
                            CardExpansion.toggle($isExpanded)
                        } label: {
                            row(item, index)
                                .frame(height: rowHeight)
                                .blur(radius: isExpanded ? 0 : DesignTokens.Size.cardPreviewBlurRadius)
                                .overlay {
                                    Rectangle()
                                        .fill(Color(.secondarySystemGroupedBackground))
                                        .mask(
                                            LinearGradient(
                                                colors: [.clear, .white.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(isExpanded ? 0 : 1)
                                        .allowsHitTesting(false)
                                }
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isExpanded)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-expand-preview-\(itemName)")
                        .accessibilityLabel(isExpanded ? "Show fewer \(itemName)" : "Show all \(itemName)")
                    } else {
                        row(item, index)
                            .frame(height: rowHeight)
                    }
                }
            }

            if !extra.isEmpty {
                ScrollView(.vertical) {
                    VStack(spacing: spacing) {
                        ForEach(Array(extra.enumerated()), id: \.element.id) { index, item in
                            row(item, index + previewCount)
                                .frame(height: rowHeight)
                        }
                    }
                    .padding(.top, spacing)
                }
                .frame(height: isExpanded ? expandedHeight : 0)
                .animation(reduceMotion ? nil : .smooth(duration: 0.42), value: isExpanded)
                .clipped()
                .scrollDisabled(!isExpanded || expandedHeight < DesignTokens.Size.cardExpandedMaxHeight)
                .scrollIndicators(isExpanded ? .visible : .hidden)
                .accessibilityHidden(!isExpanded)
            }
        }
    }
}
