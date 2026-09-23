import SwiftUI

@MainActor
private enum CardExpansion {
    static func toggle(_ expanded: Binding<Bool>, reduceMotion: Bool) {
        var transaction = Transaction(
            animation: reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4)
        )
        if #available(iOS 18.0, *) {
            transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        }
        withTransaction(transaction) {
            expanded.wrappedValue.toggle()
        }
    }
}

/// The header and the bottom chevron share exactly one expansion behavior.
struct ExpandableCardHeader<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            CardExpansion.toggle($isExpanded, reduceMotion: reduceMotion)
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
/// The outer List only animates a short height change, even for large networks.
struct ExpandableCardRows<Item: Identifiable, Row: View>: View {
    @Binding var isExpanded: Bool
    let items: [Item]
    let previewCount: Int
    let rowHeight: CGFloat
    let spacing: CGFloat
    @ViewBuilder let row: (Item, Int) -> Row

    private var extra: [Item] { Array(items.dropFirst(previewCount)) }

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
                    row(item, index)
                        .frame(height: rowHeight)
                }
            }

            if !extra.isEmpty {
                ScrollView(.vertical) {
                    LazyVStack(spacing: spacing) {
                        ForEach(Array(extra.enumerated()), id: \.element.id) { index, item in
                            row(item, index + previewCount)
                                .frame(height: rowHeight)
                        }
                    }
                    .padding(.top, spacing)
                }
                .frame(height: isExpanded ? expandedHeight : 0)
                .clipped()
                .scrollDisabled(!isExpanded || expandedHeight < DesignTokens.Size.cardExpandedMaxHeight)
                .scrollIndicators(isExpanded ? .visible : .hidden)
                .accessibilityHidden(!isExpanded)
            }
        }
    }
}

/// The fade and centered chevron occupy the card's full bottom edge.
struct ExpandableCardSurface<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        content
            .padding(.bottom, hasMore ? DesignTokens.Size.cardRevealContentInset : 0)
            .cardSurface()
            .overlay(alignment: .bottom) {
                if hasMore {
                    Button {
                        CardExpansion.toggle($isExpanded, reduceMotion: reduceMotion)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(maxWidth: .infinity)
                            .frame(height: DesignTokens.Size.cardRevealHeight)
                            .contentShape(Rectangle())
                    }
                    .background {
                        if !isExpanded {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask(
                                    LinearGradient(
                                        colors: [.clear, .white],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("card-expand-footer-\(itemName)")
                    .accessibilityLabel(isExpanded ? "Show fewer \(itemName)" : "Show all \(itemName)")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
    }
}
