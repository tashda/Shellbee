import SwiftUI

struct DeviceCardHeader: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                DeviceImageView(
                    device: device,
                    isAvailable: isAvailable,
                    hasUpdate: state.hasUpdateAvailable,
                    otaStatus: otaStatus,
                    size: DesignTokens.Size.deviceCardImage
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(device.friendlyName)
                        .font(DesignTokens.Typography.cardHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)

                    Text(vendor)
                        .font(DesignTokens.Typography.cardSubheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(model)
                        .font(.system(size: DesignTokens.Size.statusBadgeFont, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)
            }
            .padding(.trailing, DesignTokens.Size.headerLastSeenWidth)

            DeviceCardLastSeen(lastSeen: state.lastSeen)
                .frame(width: DesignTokens.Size.headerLastSeenWidth, alignment: .trailing)
                .offset(y: DesignTokens.Spacing.md)
        }
    }

    private var vendor: String {
        device.definition?.vendor ?? device.manufacturer ?? "Unknown Vendor"
    }

    private var model: String {
        device.definition?.model ?? device.modelId ?? "Unknown Model"
    }
}

#Preview {
    DeviceCardHeader(
        device: .preview,
        state: ["last_seen": .string("2026-04-20T22:24:00Z")],
        isAvailable: true,
        otaStatus: nil
    )
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
