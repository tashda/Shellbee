import SwiftUI

/// A quick-glance summary shown when tapping a node on the Network Map,
/// short of pushing all the way into the full `DeviceDetailView`. Mirrors
/// what Unifi/HA topology views surface on a node tap: image, identity,
/// what it's routing through, and link quality — the same identity row
/// and capsules as Device detail, so this is never a second design.
struct NetworkMapDeviceQuickLookSheet: View {
    let device: Device
    let node: NetworkTopologyNode
    let isOnline: Bool
    let hasWeakLink: Bool
    let connection: Connection?
    let onViewDetails: () -> Void

    struct Connection {
        let parentName: String
        let linkQuality: Int?
    }

    var body: some View {
        List {
            IdentityRow(
                name: device.friendlyName,
                subtitle: device.cardSubtitle,
                isListRow: true
            ) {
                DeviceImageView(device: device, isAvailable: isOnline, size: DesignTokens.Size.deviceRowImage)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            chipsRow
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section {
                if let connection {
                    LabeledContent("Connected To") { Text(connection.parentName) }
                    if let quality = connection.linkQuality {
                        LabeledContent("Signal") {
                            Text("\(quality)")
                                .foregroundStyle(hasWeakLink ? .red : .secondary)
                                .monospacedDigit()
                        }
                    }
                } else if node.role == .coordinator {
                    LabeledContent("Connected To") { Text("—") }
                }
                Button("Show Device", action: onViewDetails)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .networkMapQuickLookPresentationSizing()
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(chips) { chip in
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if let dotColor = chip.dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: DesignTokens.Size.statusDotHero, height: DesignTokens.Size.statusDotHero)
                        }
                        Text(chip.title)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(chip.color ?? .primary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }

    private var chips: [IdentityChip] {
        var chips = [
            IdentityChip(title: isOnline ? "Online" : "Offline", dotColor: isOnline ? .green : .red),
            IdentityChip(title: roleTitle),
        ]
        if let quality = connection?.linkQuality {
            chips.append(IdentityChip(title: "\(quality)", color: hasWeakLink ? .red : nil))
        }
        return chips
    }

    private var roleTitle: String {
        switch node.role {
        case .coordinator: return "Coordinator"
        case .router: return "Router"
        case .endDevice: return "End Device"
        case .unknown: return "Unknown"
        }
    }
}

private extension View {
    @ViewBuilder
    func networkMapQuickLookPresentationSizing() -> some View {
        if AdaptiveLayout.isPad, #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
