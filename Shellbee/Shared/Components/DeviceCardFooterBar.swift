import SwiftUI

struct DeviceCardFooterBar: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: device.type.chipLabel, label: "Type", color: deviceTypeColor)
            statCell(value: statusTitle, label: "Status", color: statusColor)
            statCell(value: linkQualityTitle, label: "Signal", color: lqiValueColor)
            powerStatCell
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(footerBackground)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignTokens.Spacing.summaryRowVerticalPadding) {
            Text(value)
                .font(DesignTokens.Typography.footerActionLabel)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var powerStatCell: some View {
        VStack(spacing: DesignTokens.Spacing.summaryRowVerticalPadding) {
            powerStatValue
            Text("Power")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var powerStatValue: some View {
        if device.type == .endDevice, let battery = state.battery {
            Text("\(battery)%")
                .font(DesignTokens.Typography.footerActionLabel)
                .foregroundStyle(battery.batteryColor)
        } else {
            Text(normalizedPowerSource)
                .font(DesignTokens.Typography.footerActionLabel)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
        }
    }

    private var footerBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(DesignTokens.Opacity.subtleFill))
                .frame(height: DesignTokens.Size.footerTopRule)

            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private var linkQualityTitle: String {
        state.linkQuality.map(String.init) ?? "—"
    }

    private var statusTitle: String {
        if let otaStatus, otaStatus.isActive {
            switch otaStatus.phase {
            case .checking: return "Checking"
            case .updating: return "Updating"
            case .requested, .scheduled: return "Starting"
            default: break
            }
        }

        if device.interviewing {
            return "Interviewing"
        }

        if !device.availabilityTrackingEnabled {
            return "Untracked"
        }

        return isAvailable ? "Online" : "Offline"
    }

    private var statusColor: Color {
        if otaStatus?.isActive == true { return .blue }
        if device.interviewing { return .orange }
        if !device.availabilityTrackingEnabled { return .secondary }
        return isAvailable ? .green : .red
    }

    private var normalizedPowerSource: String {
        let source = state["power_source"]?.stringValue ?? device.powerSource
        let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmed.isEmpty {
            return "Unknown"
        }

        let normalized = trimmed.lowercased()
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("mains") || normalized.contains("ac") || normalized.contains("dc") {
            return "Mains"
        }

        return trimmed.capitalized
    }

    private var lqiValueColor: Color {
        (state.linkQuality ?? 0).lqiColor
    }

    private var deviceTypeColor: Color {
        switch device.type {
        case .router: return .indigo
        case .endDevice: return .blue
        case .coordinator: return .purple
        case .unknown: return .secondary
        }
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        DeviceCardFooterBar(
            device: .preview,
            state: ["battery": .int(78), "linkquality": .int(96)],
            isAvailable: true,
            otaStatus: nil
        )
        DeviceCardFooterBar(
            device: Device(
                ieeeAddress: "0x003",
                type: .router,
                networkAddress: 3,
                supported: true,
                friendlyName: "Router",
                disabled: false,
                definition: nil,
                powerSource: "Mains (single phase)",
                interviewCompleted: true,
                interviewing: false
            ),
            state: ["linkquality": .int(248)],
            isAvailable: true,
            otaStatus: nil
        )
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
