import SwiftUI

struct DeviceCardHeader: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    /// When false, the last-seen label is suppressed entirely — used when
    /// z2m's `advanced.last_seen` is set to `disable`, since any retained
    /// value would be stale.
    var lastSeenEnabled: Bool = true
    var onRenameTapped: (() -> Void)? = nil

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
                    nameView

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

            DeviceCardLastSeen(lastSeen: lastSeenEnabled ? state.lastSeen : nil)
                .frame(width: DesignTokens.Size.headerLastSeenWidth, alignment: .trailing)
                .offset(y: DesignTokens.Spacing.md)
        }
    }

    @ViewBuilder
    private var nameView: some View {
        let label = Text(device.friendlyName)
            .font(DesignTokens.Typography.cardHeadline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
            .allowsTightening(true)

        if let onRenameTapped {
            Button(action: onRenameTapped) {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename device")
            .accessibilityValue(device.friendlyName)
        } else {
            label
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
