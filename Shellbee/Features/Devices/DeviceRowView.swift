import SwiftUI

struct DeviceRowView: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var checkResult: AppStore.DeviceCheckResult? = nil
    var isDeleting: Bool = false
    /// Phase 2 multi-bridge: source-bridge tag. Surfaces as a thin leading
    /// bar drawn by `BridgeRowLeadingBar` via `DeviceListRow.listRowBackground`
    /// — uniform across Devices, Groups, and Logs. The fields are kept here
    /// for callers that pass them, but the row body itself doesn't render any
    /// per-row bridge chrome.
    var bridgeID: UUID? = nil
    var bridgeName: String = ""

    private var effectiveAvailable: Bool {
        isDeleting ? false : isAvailable
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceImageView(
                device: device,
                isAvailable: effectiveAvailable,
                hasUpdate: state.hasUpdateAvailable,
                otaStatus: otaStatus,
                size: DesignTokens.Size.summaryRowSymbolFrame
            )

            VStack(alignment: .leading, spacing: 0) {
                if let vendor = device.definition?.vendor {
                    Text(vendor.uppercased())
                        .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                        .lineLimit(1)
                }

                Text(device.friendlyName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(effectiveAvailable ? .primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            rightDetailView
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var isInterviewing: Bool { device.isInterviewing }

    @ViewBuilder
    private var rightDetailView: some View {
        if isDeleting {
            Label("Deleting", systemImage: "trash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .labelStyle(.titleAndIcon)
        } else if isInterviewing {
            Label("Interviewing", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
                .labelStyle(.titleAndIcon)
        } else if let otaStatus, otaStatus.isActive {
            Text(otaPhaseLabel(otaStatus))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
        } else if let checkResult {
            checkResultLabel(checkResult)
        } else if !device.availabilityTrackingEnabled {
            Label("Untracked", systemImage: "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        } else if !isAvailable {
            Text("Offline")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
        } else {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let battery = state.battery {
                    Image(systemName: battery.batterySymbol)
                        .foregroundStyle(battery.batteryColor)
                }
                if let lqi = state.linkQuality {
                    HStack(spacing: DesignTokens.Spacing.summaryRowTextSpacing) {
                        Image(systemName: lqi.lqiSymbol)
                        Text("\(lqi)")
                    }
                    .foregroundStyle(lqi.lqiColor)
                }
            }
            .font(.caption.weight(.medium))
            .imageScale(.small)
        }
    }

    @ViewBuilder
    private func checkResultLabel(_ result: AppStore.DeviceCheckResult) -> some View {
        switch result {
        case .noUpdate:
            Label("No update", systemImage: "checkmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        case .updateFound:
            Label("Update found", systemImage: "arrow.up.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .labelStyle(.titleAndIcon)
        case .failed:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
        }
    }

    private func otaPhaseLabel(_ status: OTAUpdateStatus) -> String {
        switch status.phase {
        case .checking: return "Checking"
        case .scheduled: return "Scheduled"
        case .updating:
            if let p = status.progress { return "Updating \(Int(p))%" }
            return "Updating"
        default: return "Preparing"
        }
    }

}

#Preview {
    List {
        DeviceRowView(
            device: .preview,
            state: ["battery": .int(18), "linkquality": .int(120), "update_available": .bool(true)],
            isAvailable: true,
            otaStatus: nil
        )
        DeviceRowView(
            device: .fallbackPreview,
            state: ["battery": .int(85)],
            isAvailable: false,
            otaStatus: OTAUpdateStatus(deviceName: "Other Device", phase: .requested, progress: nil, remaining: nil)
        )
    }
    .listStyle(.insetGrouped)
}
