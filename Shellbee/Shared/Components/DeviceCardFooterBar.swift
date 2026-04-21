import SwiftUI

struct DeviceCardFooterBar: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                DeviceCardFooterChip(
                    title: device.type.chipLabel,
                    symbol: deviceTypeIcon,
                    tint: deviceTypeColor,
                    style: .semantic
                )
                DeviceCardFooterChip(
                    title: powerSummaryTitle,
                    symbol: powerSummaryIcon,
                    tint: powerSummaryTint,
                    style: powerChipStyle
                )
            }

            Spacer(minLength: DesignTokens.Size.deviceCardFooterMinSpacing)

            HStack(spacing: DesignTokens.Spacing.sm) {
                DeviceCardFooterChip(
                    title: linkQualityTitle,
                    symbol: lqiSymbol,
                    tint: lqiTint,
                    style: linkQualityChipStyle
                )
                DeviceCardFooterChip(
                    title: statusTitle,
                    symbol: statusSymbol,
                    tint: statusColor,
                    style: .semantic
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(footerBackground)
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

        return isAvailable ? "Online" : "Offline"
    }

    private var statusSymbol: String {
        if let otaStatus, otaStatus.isActive {
            switch otaStatus.phase {
            case .checking: return "magnifyingglass"
            case .updating: return "arrow.down.circle.fill"
            case .requested, .scheduled: return "arrow.trianglehead.2.clockwise.circle.fill"
            default: break
            }
        }

        if device.interviewing {
            return "hourglass"
        }

        return isAvailable ? "circle.fill" : "xmark.circle.fill"
    }

    private var statusColor: Color {
        if otaStatus?.isActive == true { return .blue }
        if device.interviewing { return .orange }
        return isAvailable ? .green : .red
    }

    private var powerSummaryTitle: String {
        if device.type == .endDevice, let battery = state.battery {
            return "\(battery)%"
        }

        return normalizedPowerSource
    }

    private var powerSummaryIcon: String {
        if device.type == .endDevice, let battery = state.battery {
            return batterySymbol(battery)
        }

        return normalizedPowerSource == "Battery" ? "battery.100" : "powerplug.fill"
    }

    private var powerSummaryTint: Color {
        if let battery = state.battery, battery < DesignTokens.Threshold.lowBattery {
            return .red
        }

        return .secondary
    }

    private var powerChipStyle: DeviceCardFooterChip.Style {
        if let battery = state.battery, battery < DesignTokens.Threshold.lowBattery {
            return .semantic
        }

        return .neutral
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

    private var lqiSymbol: String {
        let lqi = state.linkQuality ?? 0
        return lqi < DesignTokens.Threshold.weakSignal ? "wifi.exclamationmark" : "wifi"
    }

    private var lqiTint: Color {
        let lqi = state.linkQuality ?? 0

        if lqi < DesignTokens.Threshold.weakSignal { return .red }
        return .secondary
    }

    private var linkQualityChipStyle: DeviceCardFooterChip.Style {
        let lqi = state.linkQuality ?? 0
        return lqi < DesignTokens.Threshold.weakSignal ? .semantic : .neutral
    }

    private func batterySymbol(_ level: Int) -> String {
        switch level {
        case 0..<15: return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<65: return "battery.50"
        case 65..<85: return "battery.75"
        default: return "battery.100"
        }
    }

    private var deviceTypeIcon: String? {
        switch device.type {
        case .router: return "network.badge.shield.half.filled"
        case .endDevice: return "leaf"
        case .coordinator: return "hub.hop.fill"
        case .unknown: return nil
        }
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

private struct DeviceCardFooterChip: View {
    enum Style {
        case semantic
        case neutral
    }

    let title: String
    let symbol: String?
    let tint: Color
    let style: Style

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: DesignTokens.Size.compactChipSymbol, weight: .semibold))
            }

            Text(title)
                .font(.system(size: DesignTokens.Size.compactChipFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, DesignTokens.Size.compactChipHorizontalPadding)
        .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch style {
        case .semantic:
            return tint
        case .neutral:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .semantic:
            return tint.opacity(DesignTokens.Opacity.chipFill)
        case .neutral:
            return Color(.tertiarySystemFill)
        }
    }
}
