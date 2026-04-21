import SwiftUI

struct DeviceCard: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeviceCardHeader(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus)
                .padding(DesignTokens.Spacing.lg)

            Divider().opacity(DesignTokens.Opacity.subtleFill)

            DeviceCardFooterBar(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
            radius: DesignTokens.Spacing.sm,
            y: DesignTokens.Spacing.xs
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceCard(
            device: .preview,
            state: [
                "linkquality": .int(96),
                "battery": .int(100),
                "last_seen": .string("2026-04-20T22:24:00Z")
            ],
            isAvailable: true,
            otaStatus: nil
        )
        DeviceCard(
            device: Device(
                ieeeAddress: "0x003",
                type: .router,
                networkAddress: 3,
                supported: true,
                friendlyName: "krea_spot_4",
                disabled: false,
                definition: DeviceDefinition(
                    model: "LED2106R3",
                    vendor: "IKEA",
                    description: "Router preview",
                    supportsOTA: true,
                    exposes: [],
                    options: nil,
                    icon: nil
                ),
                powerSource: "Mains (single phase)",
                interviewCompleted: true,
                interviewing: false,
                softwareBuildId: "3.0.21"
            ),
            state: [
                "linkquality": .int(248),
                "last_seen": .int(Int(Date().timeIntervalSince1970 * 1000) - 300000)
            ],
            isAvailable: true,
            otaStatus: nil
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
