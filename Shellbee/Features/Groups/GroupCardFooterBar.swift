import SwiftUI

struct GroupCardFooterBar: View {
    let group: Group
    let state: [String: JSONValue]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                GroupCardFooterChip(
                    title: "\(group.members.count) \(group.members.count == 1 ? "Member" : "Members")",
                    symbol: "person.2.fill",
                    tint: .secondary,
                    style: .neutral
                )
                if !group.scenes.isEmpty {
                    GroupCardFooterChip(
                        title: "\(group.scenes.count) \(group.scenes.count == 1 ? "Scene" : "Scenes")",
                        symbol: "theatermasks.fill",
                        tint: .secondary,
                        style: .neutral
                    )
                }
            }

            Spacer(minLength: DesignTokens.Size.deviceCardFooterMinSpacing)

            if let stateValue = state["state"]?.stringValue {
                let isOn = stateValue.uppercased() == "ON"
                GroupCardFooterChip(
                    title: stateValue.uppercased(),
                    symbol: isOn ? "lightbulb.fill" : "lightbulb",
                    tint: isOn ? .yellow : .secondary,
                    style: isOn ? .semantic : .neutral
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(footerBackground)
    }

    private var footerBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(DesignTokens.Opacity.subtleFill))
                .frame(height: DesignTokens.Size.footerTopRule)
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

private struct GroupCardFooterChip: View {
    enum Style { case semantic, neutral }
    let title: String
    let symbol: String?
    let tint: Color
    let style: Style

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: DesignTokens.Size.compactChipSymbol, weight: .semibold))
            }
            Text(title)
                .font(.system(size: DesignTokens.Size.compactChipFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, DesignTokens.Size.compactChipHorizontalPadding)
        .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
        .foregroundStyle(style == .semantic ? tint : Color.secondary)
        .background(style == .semantic ? tint.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill), in: Capsule())
    }
}

#Preview {
    VStack {
        GroupCardFooterBar(group: .preview, state: ["state": .string("ON")])
        GroupCardFooterBar(group: .previewWithMembers, state: [:])
    }
    .background(Color(.secondarySystemGroupedBackground))
}
