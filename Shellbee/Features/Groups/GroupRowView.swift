import SwiftUI

struct GroupRowView: View {
    let group: Group
    let memberDevices: [Device]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            groupIcon

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.friendlyName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if memberDevices.isEmpty {
                    Text("No devices")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    memberThumbnailRow
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text("#\(group.id)")
                    .font(.system(size: DesignTokens.Size.chipFont, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)

                if !group.scenes.isEmpty {
                    Text("\(group.scenes.count) \(group.scenes.count == 1 ? "scene" : "scenes")")
                        .font(.system(size: DesignTokens.Size.chipFont, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var groupIcon: some View {
        Image(systemName: "rectangle.3.group.fill")
            .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: DesignTokens.Size.summaryRowSymbolFrame, height: DesignTokens.Size.summaryRowSymbolFrame)
            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground))
    }

    private var memberThumbnailRow: some View {
        MemberAvatarStack(devices: memberDevices, size: 24)
    }
}

#Preview {
    List {
        GroupRowView(group: .preview, memberDevices: [])
        GroupRowView(group: .previewWithMembers, memberDevices: [.preview, .fallbackPreview, .preview])
    }
    .listStyle(.plain)
}
