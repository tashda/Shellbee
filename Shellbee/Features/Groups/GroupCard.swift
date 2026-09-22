import SwiftUI

struct GroupCard: View {
    let group: Group
    let memberDevices: [Device]
    let state: [String: JSONValue]
    var bridgeID: UUID? = nil
    var bridgeName: String? = nil
    /// How many members report ON, for "2 of 3 on".
    var membersOnCount: Int? = nil
    var onRenameTapped: (() -> Void)? = nil
    var onNameHiddenChange: ((Bool) -> Void)? = nil
    var displayMode: DeviceIdentityDisplayMode = .prominent

    @State private var showAvatarPicker = false
    @State private var avatarSelection: [String] = []

    /// Avatar reflects the @State selection so changes from the picker
    /// re-render this view immediately. Falls back to first-two when no
    /// selection or none of the stored IEEEs are still members.
    private var avatarDevices: [Device] {
        if !avatarSelection.isEmpty {
            let pick = avatarSelection.compactMap { ieee in
                memberDevices.first { $0.ieeeAddress == ieee }
            }
            if !pick.isEmpty { return Array(pick.prefix(2)) }
        }
        return Array(memberDevices.prefix(2))
    }

    var body: some View {
        switch displayMode {
        case .prominent: hero
        case .compact: row
        }
    }

    private var hero: some View {
        IdentityHero(
            name: group.friendlyName,
            subtitle: subtitle,
            bridgeID: bridgeID,
            bridgeName: bridgeName,
            chips: chips,
            renameAccessibilityLabel: "Rename group",
            onRenameTapped: onRenameTapped,
            onNameHiddenChange: onNameHiddenChange
        ) {
            Button {
                let stored = GroupAvatarStore.shared.selection(for: group)
                avatarSelection = stored.isEmpty
                    ? Array(memberDevices.prefix(2).map(\.ieeeAddress))
                    : stored
                showAvatarPicker = true
            } label: {
                GroupIconView(memberDevices: avatarDevices, size: DesignTokens.Size.deviceHeroImage)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose group avatar")
        }
        .sheet(isPresented: $showAvatarPicker) {
            GroupAvatarPickerSheet(
                group: group,
                memberDevices: memberDevices,
                selectedIEEEs: $avatarSelection
            )
        }
        .onAppear {
            avatarSelection = GroupAvatarStore.shared.selection(for: group)
        }
    }

    private var row: some View {
        IdentityRow(
            name: group.friendlyName,
            subtitle: "Group · \(membersText)",
            bridgeID: bridgeID,
            bridgeName: bridgeName
        ) {
            GroupIconView(memberDevices: avatarDevices, size: DesignTokens.Size.deviceRowImage)
        }
    }

    /// "Group 208", plus the description when the group has one.
    private var subtitle: String {
        if let description = group.description, !description.isEmpty {
            return "Group \(group.id) · \(description)"
        }
        return "Group \(group.id)"
    }

    private var membersText: String {
        group.members.count == 1 ? "1 member" : "\(group.members.count) members"
    }

    private var chips: [IdentityChip] {
        var chips: [IdentityChip] = []
        if let stateText {
            chips.append(IdentityChip(title: stateText, dotColor: anyOn ? .green : Color(.tertiaryLabel)))
        }
        chips.append(IdentityChip(title: membersText))
        if !group.scenes.isEmpty {
            chips.append(IdentityChip(title: group.scenes.count == 1 ? "1 scene" : "\(group.scenes.count) scenes"))
        }
        return chips
    }

    private var anyOn: Bool {
        membersOnCount.map { $0 > 0 } ?? isOn
    }

    private var isOn: Bool {
        state["state"]?.stringValue?.uppercased() == "ON"
    }

    /// "2 of 3 on" when member states are known, otherwise the group state.
    private var stateText: String? {
        if let membersOnCount, !group.members.isEmpty {
            return "\(membersOnCount) of \(group.members.count) on"
        }
        guard state["state"]?.stringValue != nil else { return nil }
        return isOn ? "On" : "Off"
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GroupCard(group: .preview, memberDevices: [], state: ["state": .string("ON")])
        GroupCard(group: .previewWithMembers, memberDevices: [.preview, .fallbackPreview], state: [:])
        GroupCard(group: .previewWithMembers, memberDevices: [.preview, .fallbackPreview], state: [:], displayMode: .compact)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
