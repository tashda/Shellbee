import SwiftUI

struct DeviceCard: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var onRenameTapped: (() -> Void)? = nil

    private var isUpdating: Bool { otaStatus?.isActive == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeviceCardHeader(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus, onRenameTapped: onRenameTapped)
                .padding(DesignTokens.Spacing.lg)
                .opacity(isUpdating ? 0.75 : 1)

            if let otaStatus, otaStatus.isActive {
                otaProgressStrip(status: otaStatus)
            }

            Divider().opacity(DesignTokens.Opacity.subtleFill)

            DeviceCardFooterBar(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus)
        }
        .animation(.easeInOut(duration: 0.2), value: isUpdating)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
            radius: DesignTokens.Spacing.sm,
            y: DesignTokens.Spacing.xs
        )
    }

    @ViewBuilder
    private func otaProgressStrip(status: OTAUpdateStatus) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(phaseCaption(for: status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let progress = status.progress {
                    Text("\(Int(progress))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let progress = status.progress {
                ProgressView(value: progress, total: 100)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .tint(.blue)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.md)
        .transition(.opacity)
    }

    private func phaseCaption(for status: OTAUpdateStatus) -> String {
        switch status.phase {
        case .checking: return "Checking for update"
        case .requested, .scheduled: return "Starting update"
        case .updating: return "Updating firmware"
        default: return status.phase.rawValue.capitalized
        }
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
