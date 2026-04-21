import SwiftUI

struct RemoveDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let onConfirm: (Bool, Bool) -> Void

    @State private var forceRemove = false
    @State private var blockJoining = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Remove Device")
                    .font(.title3.weight(.semibold))
                Text("This removes the device from Zigbee2MQTT.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    DeviceImageView(
                        device: device,
                        isAvailable: true,
                        size: DesignTokens.Size.deviceActionSheetImage
                    )
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(device.friendlyName)
                            .font(.headline)
                        Text(device.definition?.model ?? "Unknown Model")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Toggle("Force Remove", isOn: $forceRemove)
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xs)
                Toggle("Block from joining", isOn: $blockJoining)
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            if forceRemove || blockJoining {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    if forceRemove {
                        Label(
                            "Force remove deletes the device even without a leave response.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                    if blockJoining {
                        Label(
                            "Device will be blocklisted from rejoining the network.",
                            systemImage: "nosign"
                        )
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 0)

            Button("Remove Device", role: .destructive) {
                onConfirm(forceRemove, blockJoining)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    RemoveDeviceSheet(device: .preview) { _, _ in }
}
