import SwiftUI

struct HomeAddCardsSection: View {
    let hidden: [HomeCardID]
    let onAdd: (HomeCardID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Add Cards")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DesignTokens.Spacing.md)

            HomeCardContainer {
                VStack(spacing: 0) {
                    ForEach(Array(hidden.enumerated()), id: \.element) { index, card in
                        Button { onAdd(card) } label: {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                                Image(systemName: card.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(card.tint)
                                    .frame(width: DesignTokens.Size.cardSymbol)
                                Text(card.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < hidden.count - 1 {
                            Divider().padding(.leading, DesignTokens.Size.homeAddDividerInset)
                        }
                    }
                }
            }
        }
    }
}
