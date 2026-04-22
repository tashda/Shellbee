import SwiftUI

struct GroupCard: View {
    let group: Group
    let memberDevices: [Device]
    let state: [String: JSONValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupCardHeader(group: group, memberDevices: memberDevices)
                .padding(DesignTokens.Spacing.lg)

            Divider().opacity(DesignTokens.Opacity.subtleFill)

            GroupCardFooterBar(group: group, state: state)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
            radius: DesignTokens.Spacing.sm,
            y: DesignTokens.Spacing.xs
        )
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GroupCard(group: .preview, memberDevices: [], state: ["state": .string("ON")])
        GroupCard(group: .previewWithMembers, memberDevices: [.preview, .fallbackPreview], state: [:])
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
