import SwiftUI

@MainActor
private enum CardExpansion {
    static func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        if #available(iOS 18.0, *) {
            transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        }
        withTransaction(transaction, changes)
    }

    static func toggle(_ expanded: Binding<Bool>) {
        withoutAnimation {
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
    @State private var revealHeight: CGFloat = 0
    @State private var revealOpacity = 0.0
    @State private var previewIsFaded = true
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
                                        .opacity(previewIsFaded ? 1 : 0)
                                        .allowsHitTesting(false)
                                }
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white.opacity(previewIsFaded ? 0.12 : 1), location: 1),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
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
                                .opacity(index < 12 ? revealOpacity : 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, spacing)
                }
                .frame(height: revealHeight)
                .clipped()
                .accessibilityHidden(!isExpanded)
            }
        }
        .onAppear {
            previewIsFaded = !isExpanded
            if isExpanded {
                revealHeight = expandedHeight
                revealOpacity = 1
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            animateReveal(expanded)
        }
        .transaction { transaction in
            if #available(iOS 18.0, *) {
                transaction.scrollContentOffsetAdjustmentBehavior = .disabled
            }
        }
    }

    private func animateReveal(_ expanded: Bool) {
        if reduceMotion {
            CardExpansion.withoutAnimation {
                revealHeight = expanded ? expandedHeight : 0
                revealOpacity = expanded ? 1 : 0
                previewIsFaded = !expanded
            }
            return
        }

        if expanded {
            withAnimation(.easeOut(duration: 0.12)) {
                previewIsFaded = false
            }
            withAnimation(.easeIn(duration: 0.85)) {
                revealHeight = expandedHeight
            }
            withAnimation(.easeOut(duration: 0.35)) {
                revealOpacity = 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.72), completionCriteria: .logicallyComplete) {
                revealHeight = 0
            } completion: {
                guard !isExpanded else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    previewIsFaded = true
                }
            }
            withAnimation(.easeIn(duration: 0.28).delay(0.32)) {
                revealOpacity = 0
            }
        }
    }
}
