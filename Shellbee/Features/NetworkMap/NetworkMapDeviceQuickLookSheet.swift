import SwiftUI

/// A quick-glance summary shown when tapping a node on the Network Map,
/// short of pushing all the way into the full `DeviceDetailView`. Mirrors
/// what Unifi/HA topology views surface on a node tap: image, identity,
/// what it's routing through, and link quality.
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
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    DeviceImageView(device: device, isAvailable: isOnline, size: DesignTokens.Size.networkMapQuickLookImage)
                    Text(device.friendlyName)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if let model = modelText {
                        Text(model)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, DesignTokens.Spacing.sm)

                VStack(spacing: 0) {
                    row("Status", value: isOnline ? "Online" : "Offline", valueColor: isOnline ? .green : .secondary)
                    Divider()
                    row("Role", value: node.role.rawValue)
                    if let connection {
                        Divider()
                        row("Connected To", value: connection.parentName)
                        if let quality = connection.linkQuality {
                            Divider()
                            row("LQI", value: "\(quality)", valueColor: hasWeakLink ? .red : .primary)
                        }
                    } else if node.role == .coordinator {
                        Divider()
                        row("Connected To", value: "—")
                    }
                    if let manufacturer = device.manufacturer {
                        Divider()
                        row("Manufacturer", value: manufacturer)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))

                Button("View Full Details", action: onViewDetails)
                    .glassProminentButtonStyleIfAvailable()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var modelText: String? {
        node.modelID ?? device.modelId
    }

    private func row(_ label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
        .font(.subheadline)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}
