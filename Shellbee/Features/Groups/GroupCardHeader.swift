import SwiftUI

struct GroupCardHeader: View {
    let group: Group
    let memberDevices: [Device]
    var onRenameTapped: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            avatarArea

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                nameView

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

    @ViewBuilder
    private var nameView: some View {
        let label = Text(group.friendlyName)
            .font(DesignTokens.Typography.cardHeadline)
            .foregroundStyle(.primary)
            .lineLimit(2)

        if let onRenameTapped {
            Button(action: onRenameTapped) {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename group")
            .accessibilityValue(group.friendlyName)
        } else {
            label
        }
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
