import SwiftUI

struct DeviceRowView: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
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
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let otaStatus, otaStatus.isActive {
                        updatingChip(for: otaStatus)
                    }
                    statusChip
                    batteryChip
                }
                .padding(.top, DesignTokens.Spacing.xs)
            }

            Spacer()

            rightDetailView
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private func updatingChip(for status: OTAUpdateStatus) -> some View {
        let title: String = {
            switch status.phase {
            case .checking: return "Checking"
            case .updating:
                if let progress = status.progress {
                    return "Updating \(Int(progress))%"
                }
                return "Updating"
            default: return "Preparing"
            }
        }()

        let icon: String = {
            switch status.phase {
            case .checking: return "magnifyingglass"
            case .updating: return "arrow.down.circle.fill"
            default:        return "arrow.trianglehead.2.clockwise.circle.fill"
            }
        }()

        StatusChip(
            title: title,
            symbol: icon,
            tint: .blue
        )
    }

    @ViewBuilder
    private var statusChip: some View {
        StatusChip(
            title: isAvailable ? "Online" : "Offline",
            symbol: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill",
            tint: isAvailable ? .green : .red
        )
    }

    @ViewBuilder
    private var batteryChip: some View {
        if let battery = state.battery {
            StatusChip(
                title: "\(battery)%",
                symbol: batterySymbol(battery),
                tint: battery < 20 ? .red : .secondary
            )
        }
    }

    @ViewBuilder
    private var rightDetailView: some View {
        if isAvailable, let lqi = state.linkQuality {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("\(lqi)")
                Image(systemName: lqiSymbol(lqi))
                    .imageScale(.small)
            }
            .font(.system(size: DesignTokens.Size.chipFont, weight: .medium, design: .monospaced))
            .foregroundStyle(lqiColor(lqi))
        }
    }

    private func lqiColor(_ lqi: Int) -> Color {
        if lqi < DesignTokens.Threshold.weakSignal { return .red }
        if lqi < 80 { return .orange }
        if lqi < 150 { return .blue }
        return .green
    }

    private func lqiSymbol(_ lqi: Int) -> String {
        lqi < DesignTokens.Threshold.weakSignal ? "wifi.exclamationmark" : "wifi"
    }

    private func batterySymbol(_ level: Int) -> String {
        switch level {
        case 0..<15:  return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<65: return "battery.50"
        case 65..<85: return "battery.75"
        default:      return "battery.100"
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
