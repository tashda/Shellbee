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

/// Keeps a card's first rows fixed while revealing the rest in the page's scroll view.
/// Only the extra rows' viewport animates, keeping the card header anchored.
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
        CGFloat(extra.count) * rowHeight
            + CGFloat(max(extra.count - 1, 0)) * spacing
            + spacing
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
                                .overlay {
                                    row(item, index)
                                        .frame(height: rowHeight)
                                        .blur(radius: DesignTokens.Size.cardPreviewBlurRadius)
                                        .mask(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: .clear, location: 0),
                                                    .init(color: .white, location: 1),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(isExpanded ? 0 : 1)
                                        .allowsHitTesting(false)
                                }
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white.opacity(isExpanded ? 1 : 0.12), location: 1),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
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
                GeometryReader { _ in
                    VStack(spacing: spacing) {
                        ForEach(Array(extra.enumerated()), id: \.element.id) { index, item in
                            row(item, index + previewCount)
                                .frame(height: rowHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, spacing)
                }
                .frame(height: isExpanded ? expandedHeight : 0)
                .animation(reduceMotion ? nil : .smooth(duration: 0.42), value: isExpanded)
                .clipped()
                .accessibilityHidden(!isExpanded)
            }
        }
    }
}
