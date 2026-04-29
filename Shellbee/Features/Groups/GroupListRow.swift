import SwiftUI

struct GroupListRow: View {
    let group: Group
    let memberDevices: [Device]
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        NavigationLink(value: group) {
            GroupRowView(group: group, memberDevices: memberDevices)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onRemove) {
                swipeActionLabel("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button(action: onRename) {
                swipeActionLabel("Rename", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove Group", systemImage: "trash")
            }
        }
    }

    private func swipeActionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: DesignTokens.Size.metricSymbol - 2, weight: .semibold))
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorAggressiveLight)
        }
        .frame(minWidth: DesignTokens.Size.deviceActionSheetImage)
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
}
