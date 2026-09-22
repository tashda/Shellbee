import SwiftUI

struct HomeCardsCollection<CardContent: View, EmptyContent: View>: View {
    @Bindable var layout: HomeLayoutStore
    let usesWideLayout: Bool
    let cards: [HomeCardInstance]
    @ViewBuilder let cardContent: (HomeCardInstance) -> CardContent
    @ViewBuilder let emptyContent: () -> EmptyContent

    var body: some View {
        if usesWideLayout, !layout.isEditing {
            grid
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(cards) { card in
                    cardSlot(for: card)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(cardInsets)
                }
                .onMove { source, destination in
                    layout.move(cards: cards, from: source, to: destination)
                }
            }

            if layout.isEditing, !layout.hidden.isEmpty {
                Section {
                    addCardsSection
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(addCardsInsets)
                }
            }

            if cards.isEmpty {
                emptyContent()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(layout.isEditing ? .active : .inactive))
    }

    private var grid: some View {
        ScrollView {
            if cards.isEmpty {
                emptyContent()
                    .padding(.horizontal, DesignTokens.Spacing.lg)
            } else {
                Grid(
                    horizontalSpacing: DesignTokens.Spacing.lg,
                    verticalSpacing: DesignTokens.Spacing.lg
                ) {
                    ForEach(wideRows) { row in
                        wideGridRow(row)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.lg)
            }
        }
    }

    private var addCardsSection: some View {
        HomeAddCardsSection(
            hidden: HomeCardID.allCases.filter { layout.hidden.contains($0) }
        ) { card in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                layout.show(card)
            }
        }
    }

    private func cardSlot(for card: HomeCardInstance) -> some View {
        HomeCardSlot(
            card: card,
            isEditing: layout.isEditing,
            onHide: {
                withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                    layout.hide(card.type)
                }
            },
            onEnterEdit: {
                withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                    layout.isEditing = true
                }
            }
        ) {
            cardContent(card)
        }
    }

    @ViewBuilder
    private func wideGridRow(_ row: WideRow) -> some View {
        GridRow(alignment: .top) {
            if row.isFullWidth, let card = row.cards.first {
                cardSlot(for: card)
                    .gridCellColumns(2)
            } else {
                ForEach(row.cards) { card in
                    cardSlot(for: card)
                }
                if row.cards.count == 1 {
                    Color.clear
                }
            }
        }
    }

    private var wideRows: [WideRow] {
        var rows: [WideRow] = []
        var pendingCard: HomeCardInstance?

        for card in cards {
            if card.type == .recentEvents {
                if let pending = pendingCard {
                    rows.append(WideRow(cards: [pending]))
                }
                rows.append(WideRow(cards: [card], isFullWidth: true))
                pendingCard = nil
            } else if let pending = pendingCard {
                rows.append(WideRow(cards: [pending, card]))
                pendingCard = nil
            } else {
                pendingCard = card
            }
        }

        if let pending = pendingCard {
            rows.append(WideRow(cards: [pending]))
        }
        return rows
    }

    private var cardInsets: EdgeInsets {
        EdgeInsets(
            top: DesignTokens.Spacing.sm,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.sm,
            trailing: DesignTokens.Spacing.lg
        )
    }

    private var addCardsInsets: EdgeInsets {
        EdgeInsets(
            top: DesignTokens.Spacing.md,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.lg,
            trailing: DesignTokens.Spacing.lg
        )
    }

    private struct WideRow: Identifiable {
        let cards: [HomeCardInstance]
        var isFullWidth = false

        var id: String {
            cards.map(\.id).joined(separator: "-")
        }
    }
}
