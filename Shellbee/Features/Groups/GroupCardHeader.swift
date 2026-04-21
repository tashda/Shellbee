import SwiftUI

struct GroupCardHeader: View {
    let group: Group

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            avatarArea

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.friendlyName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

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
        Image(systemName: "rectangle.3.group.fill")
            .font(.system(size: DesignTokens.Size.deviceCardImage * 0.45, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: DesignTokens.Size.deviceCardImage, height: DesignTokens.Size.deviceCardImage)
            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GroupCardHeader(group: .preview)
        GroupCardHeader(group: .previewWithMembers)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
