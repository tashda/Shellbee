import SwiftUI

struct StatusChip: View {
    let title: String
    let symbol: String?
    let tint: Color

    init(title: String, symbol: String? = nil, tint: Color = .accentColor) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    init(_ item: some ChipRepresentable) {
        self.title = item.chipLabel
        self.symbol = item.chipIcon
        self.tint = item.chipTint
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Size.chipVerticalPadding)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}
