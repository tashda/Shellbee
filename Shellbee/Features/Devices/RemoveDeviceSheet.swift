import SwiftUI

struct RemoveDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let onConfirm: (Bool, Bool) -> Void

    @State private var forceRemove = false
    @State private var blockJoining = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    }
                }

                Section {
                    Toggle("Force Remove", isOn: $forceRemove)
                    Toggle("Block from joining", isOn: $blockJoining)
                } footer: {
                    if forceRemove && blockJoining {
                        Text("Force remove deletes the device even without a leave response. The device will also be blocklisted from rejoining the network.")
                    } else if forceRemove {
                        Text("Force remove deletes the device even without a leave response.")
                    } else if blockJoining {
                        Text("Device will be blocklisted from rejoining the network.")
                    } else {
                        Text("This removes the device from Zigbee2MQTT.")
                    }
                }
            }
            .navigationTitle("Remove Device")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var actionBar: some View {
        Button("Remove Device", role: .destructive) {
            onConfirm(forceRemove, blockJoining)
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

#Preview {
    RemoveDeviceSheet(device: .preview) { _, _ in }
}
