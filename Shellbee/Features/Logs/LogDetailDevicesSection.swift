import SwiftUI

struct LogDetailDevicesSection: View {
    @Environment(AppEnvironment.self) private var environment
    /// Phase 1 multi-bridge: log entries belong to a bridge; the listed
    /// devices reference that same bridge's store. Push to detail using the
    /// log entry's source bridge.
    let bridgeID: UUID
    let devices: [(ref: LogContext.DeviceRef, device: Device)]

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    var body: some View {
        Section("Devices") {
            ForEach(devices, id: \.device.ieeeAddress) { ref, device in
                ZStack {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        DeviceImageView(
                            device: device,
                            isAvailable: scope.store.isAvailable(device.friendlyName),
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
                    NavigationLink(value: DeviceRoute(bridgeID: bridgeID, device: device)) { EmptyView() }
                        .opacity(0)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            LogDetailDevicesSection(bridgeID: UUID(), devices: [])
        }
        .environment(AppEnvironment())
    }
}
