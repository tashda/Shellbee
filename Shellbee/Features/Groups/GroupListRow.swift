import SwiftUI

struct GroupListRow: View {
    @Environment(\.isSelectableListContext) private var isSelectableListContext

    let group: Group
    let memberDevices: [Device]
    /// Phase 1 multi-bridge: optional source-bridge id. When non-nil the row
    /// pushes a `GroupRoute` so the destination resolves against the right
    /// bridge. Nil → fall back to the legacy `Group`-value navigation
    /// (single-bridge callers that haven't been migrated yet).
    var bridgeID: UUID? = nil
    let onRename: () -> Void
    let onRemove: () -> Void
    /// Drag a device row onto this group to add it as a member. Returns
    /// `true` only when the drop is accepted (the caller still surfaces its
    /// own confirmation/feedback alert either way).
    var onDropDevice: ((DeviceTransferPayload) -> Bool)? = nil

    @State private var isDropTargeted = false

    var body: some View {
        // The drop-highlight background only replaces the row's default
        // (unset) background while a drag is over it — applying
        // `.listRowBackground` unconditionally would also blank out the
        // native selection tint in iPad 3-column mode.
        if isDropTargeted {
            rowContent.listRowBackground(Color.accentColor.opacity(DesignTokens.Opacity.chipFill))
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        navContent
        // Multi-bridge attribution: thin colored bar on the leading edge.
        // Skipped in iPad 3-column mode — see DeviceListRow for the
        // selection-chrome interaction.
        .modifier(BridgeRowLeadingBarBackground(bridgeID: bridgeID, enabled: !isSelectableListContext))
        .dropDestination(for: DeviceTransferPayload.self) { payloads, _ in
            guard let onDropDevice, payloads.count == 1, let payload = payloads.first else { return false }
            return onDropDevice(payload)
        } isTargeted: { isDropTargeted = $0 }
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
        .iPadPointerEffect(.highlight)
    }

    @ViewBuilder
    private var navContent: some View {
        if let bridgeID {
            NavigationLink(value: GroupRoute(bridgeID: bridgeID, group: group)) {
                GroupRowView(group: group, memberDevices: memberDevices)
            }
        } else {
            NavigationLink(value: group) {
                GroupRowView(group: group, memberDevices: memberDevices)
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
    .forceSoftTopScrollEdgeEffect()
}
