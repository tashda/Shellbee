import SwiftUI

struct DeviceTransferPreview: View {
    let device: Device
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
                hasUpdate: false,
                otaStatus: otaStatus,
                size: DesignTokens.Size.summaryRowSymbolFrame
            )
            Text(device.friendlyName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial, in: Capsule())
    }
}
