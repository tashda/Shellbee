import SwiftUI

struct GroupRowView: View {
    let group: Group
    let memberDevices: [Device]
    /// The source bridge, marked with its monogram before the member count.
    var bridgeID: UUID? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            groupLeadingVisual

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.friendlyName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let bridgeID {
                        BridgeMonogram(bridgeID: bridgeID, size: DesignTokens.Size.bridgeMonogramCompact)
                    }
                    Text(memberSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text("#\(group.id)")
                    .font(.system(size: DesignTokens.Size.chipFont, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var groupLeadingVisual: some View {
        GroupIconView(
            memberDevices: GroupAvatarStore.shared.resolvedDevices(for: group, members: memberDevices),
            size: DesignTokens.Size.summaryRowSymbolFrame
        )
    }

    private var memberSubtitle: String {
        let count = group.members.count
        let deviceText = count == 0 ? "No devices" : "\(count) \(count == 1 ? "device" : "devices")"
        guard !group.scenes.isEmpty else { return deviceText }
        let s = group.scenes.count
        return "\(deviceText) · \(s) \(s == 1 ? "scene" : "scenes")"
    }
}

#Preview {
    NavigationStack {
        List {
            GroupListRow(
                group: .preview,
                memberDevices: [],
                onRename: {},
                onRemove: {}
            )
            GroupListRow(
                group: .previewWithMembers,
                memberDevices: [.preview, .fallbackPreview],
                onRename: {},
                onRemove: {}
            )
        }
    }
    .configuredTopScrollEdgeEffect()
}
