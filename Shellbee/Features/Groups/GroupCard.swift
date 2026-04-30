import SwiftUI

struct GroupCard: View {
    let group: Group
    let memberDevices: [Device]
    let state: [String: JSONValue]
    var onRenameTapped: (() -> Void)? = nil
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
        case .prominent:
            prominentHeader
        case .compact:
            compactHeader
        }
    }

    private var prominentHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            identityRow
            hairline
            metricsGrid
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        .sheet(isPresented: $showAvatarPicker) {
            GroupAvatarPickerSheet(
                group: group,
                memberDevices: memberDevices,
                selectedIEEEs: $avatarSelection
            )
        }
        .onAppear {
            avatarSelection = GroupAvatarStore.load(for: group)
        }
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            GroupIconView(memberDevices: memberDevices, size: DesignTokens.Size.deviceCardImage * 0.68)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(group.friendlyName)
                    .font(DesignTokens.Typography.compactCardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMildLight)

                Text("Group #\(group.id) · \(group.members.count) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: DesignTokens.Spacing.sm)

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
                statusPill
                Text(scenesTitle == "—" ? "No scenes" : "\(scenesTitle) scenes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var identityRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            Button {
                let stored = GroupAvatarStore.load(for: group)
                avatarSelection = stored.isEmpty
                    ? Array(memberDevices.prefix(2).map(\.ieeeAddress))
                    : stored
                showAvatarPicker = true
            } label: {
                GroupIconView(memberDevices: avatarDevices, size: DesignTokens.Size.deviceCardImage * 0.80)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose group avatar")

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                nameView

                Text("Group #\(group.id)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(DesignTokens.Typography.scaleFactorSubtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading),
                GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: DesignTokens.Spacing.xl
        ) {
            identityMetric(label: "Type", icon: "square.on.square.fill", value: "Group", unit: nil, color: .indigo)
            identityMetric(label: "State", icon: stateIcon, value: stateTitle, unit: nil, color: stateColor)
            identityMetric(label: "Members", icon: "person.2.fill", value: "\(group.members.count)", unit: nil, color: .blue)
            identityMetric(label: "Scenes", icon: "sparkles", value: scenesTitle, unit: nil, color: .purple)
        }
    }

    private func identityMetric(label: String, icon: String, value: String, unit: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(DesignTokens.Typography.identityTileValue)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorTight)
                if let unit {
                    Text(unit)
                        .font(DesignTokens.Typography.identityTileUnit)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        Text(stateTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(stateColor)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(stateColor.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }

    @ViewBuilder
    private var nameView: some View {
        let label = Text(group.friendlyName)
            .font(DesignTokens.Typography.cardTitle)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(DesignTokens.Typography.scaleFactorAggressive)
            .allowsTightening(true)

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

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
            .frame(height: DesignTokens.Size.hairline)
    }

    private var scenesTitle: String {
        group.scenes.isEmpty ? "—" : "\(group.scenes.count)"
    }

    private var stateTitle: String {
        guard let value = state["state"]?.stringValue else { return "—" }
        return value.uppercased()
    }

    private var stateColor: Color {
        guard let value = state["state"]?.stringValue else { return .secondary }
        return value.uppercased() == "ON" ? .green : .secondary
    }

    private var stateIcon: String {
        guard let value = state["state"]?.stringValue else { return "circle.dashed" }
        return value.uppercased() == "ON" ? "power.circle.fill" : "power.circle"
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
