import SwiftUI

struct GroupCardHeader: View {
    let group: Group
    let memberDevices: [Device]

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            avatarArea

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.friendlyName)
                    .font(DesignTokens.Typography.cardHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)

                Text("#\(group.id)")
                    .font(.system(size: DesignTokens.Size.statusBadgeFont, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: DesignTokens.Size.statusBadgeFont))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var avatarArea: some View {
        GroupIconView(memberDevices: memberDevices, size: DesignTokens.Size.deviceCardImage)
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GroupCardHeader(group: .preview, memberDevices: [])
        GroupCardHeader(group: .previewWithMembers, memberDevices: [.preview, .fallbackPreview])
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
