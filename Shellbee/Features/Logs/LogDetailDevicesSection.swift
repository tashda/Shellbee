import SwiftUI

struct LogDetailDevicesSection: View {
    @Environment(AppEnvironment.self) private var environment
    let devices: [(ref: LogContext.DeviceRef, device: Device)]

    var body: some View {
        Section("Devices") {
            ForEach(devices, id: \.device.ieeeAddress) { ref, device in
                ZStack {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        DeviceImageView(
                            device: device,
                            isAvailable: environment.store.isAvailable(device.friendlyName),
                            size: DesignTokens.Size.logRowDeviceImage
                        )
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(device.friendlyName)
                                .font(.subheadline.weight(.medium))
                            if let role = ref.role {
                                Text(role.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    NavigationLink(destination: DeviceDetailView(device: device)) { EmptyView() }
                        .opacity(0)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            LogDetailDevicesSection(devices: [])
        }
        .environment(AppEnvironment())
    }
}
