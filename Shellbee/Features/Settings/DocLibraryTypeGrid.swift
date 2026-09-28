import SwiftUI

/// Two-column grid of device types on the Device Library home. Each tile is
/// navigation, drawn on the same surface as a row.
struct DocLibraryTypeGrid: View {
    let entries: [DocBrowserEntry]
    let onSelect: (DocLibraryScope) -> Void

    private let columns = [GridItem(.adaptive(minimum: DesignTokens.Size.libraryTileMinimumWidth), spacing: DesignTokens.Spacing.md)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
            ForEach(scopes, id: \.scope) { item in
                Button { onSelect(item.scope) } label: {
                    tile(item.scope, count: item.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile(_ scope: DocLibraryScope, count: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: scope.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(scope.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
                Text(count.formatted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .cardSurface(padding: DesignTokens.Spacing.md)
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var scopes: [(scope: DocLibraryScope, count: Int)] {
        let counts = Dictionary(grouping: entries) { $0.deviceType }.mapValues(\.count)
        let types: [(scope: DocLibraryScope, count: Int)] = DocDeviceType.allCases.compactMap { type in
            guard let count = counts[type], count > 0 else { return nil }
            return (.type(type), count)
        }
        guard let other = counts[nil], other > 0 else { return types }
        return types + [(.other, other)]
    }
}
