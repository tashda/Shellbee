import SwiftUI

/// The fan's extra features (Behaviour, Indicators and so on) drawn as
/// card-style sections, for surfaces that aren't backed by a `List`.
/// DeviceDetailView uses `FanFeatureSections` instead.
struct FanInlineSections: View {
    let context: FanControlContext
    let extras: [Expose]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var presentedGroup: IndexedGroup?

    private let rowHorizontalPadding: CGFloat = DesignTokens.Spacing.lg
    private let rowVerticalPadding: CGFloat = DesignTokens.Spacing.md
    private let rowIconWidth: CGFloat = DesignTokens.Size.cardSymbol

    var body: some View {
        ForEach(FeatureLayout.sections(from: extras)) { section in
            sectionView(section)
        }
        .sheet(item: $presentedGroup) { group in
            FeatureDetailSheet(title: group.label) {
                ForEach(Array(group.members.enumerated()), id: \.element.property) { idx, e in
                    if idx > 0 { rowDivider }
                    row(e)
                }
            }
        }
    }

    private func sectionView(_ section: LayoutSection) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(section.title)
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundStyle(.secondary)
                .padding(.leading, DesignTokens.Spacing.lg)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { rowDivider }
                    itemView(item)
                }
            }
            .cardSurface(padding: 0)
        }
    }

    @ViewBuilder
    private func itemView(_ item: LayoutItem) -> some View {
        switch item {
        case .row(let expose):
            row(expose)
        case .indexedGroup(let group):
            DisclosureRow(
                symbol: group.symbol,
                label: group.label,
                trailingSummary: "\(group.members.count)",
                horizontalPadding: rowHorizontalPadding,
                verticalPadding: rowVerticalPadding,
                iconWidth: rowIconWidth
            ) { presentedGroup = group }
        }
    }

    private func row(_ expose: Expose) -> some View {
        FanExtraRow(expose: expose, state: context.state, mode: mode,
                    horizontalPadding: rowHorizontalPadding,
                    verticalPadding: rowVerticalPadding,
                    iconWidth: rowIconWidth,
                    onSend: onSend)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, rowHorizontalPadding + rowIconWidth + DesignTokens.Spacing.md)
    }
}

private struct DisclosureRow: View {
    let symbol: String
    let label: String
    let trailingSummary: String?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: symbol)
                    .font(DesignTokens.Typography.formRowIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: iconWidth)
                Text(label).font(.body).foregroundStyle(.primary)
                Spacer()
                if let trailingSummary {
                    Text(trailingSummary).font(.body).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
