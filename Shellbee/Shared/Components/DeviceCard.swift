import SwiftUI

enum DeviceIdentityDisplayMode {
    case prominent
    case compact
}

struct DeviceCard: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var lastSeenEnabled: Bool = true
    var onRenameTapped: (() -> Void)? = nil
    var displayMode: DeviceIdentityDisplayMode = .prominent

    private var isUpdating: Bool { otaStatus?.isActive == true }

    var body: some View {
        switch displayMode {
        case .prominent:
            prominentHeader
        case .compact:
            compactHeader
        }
    }

    private var prominentHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            identityRow
                .opacity(isUpdating ? 0.75 : 1)

            if let otaStatus, otaStatus.isActive {
                otaProgressStrip(status: otaStatus)
            }

            hairline
            metricsGrid
        }
        .animation(.easeInOut(duration: DesignTokens.Duration.fastFade), value: isUpdating)
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
                hasUpdate: state.hasUpdateAvailable,
                otaStatus: otaStatus,
                size: DesignTokens.Size.deviceCardImage * 0.68
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(device.friendlyName)
                    .font(DesignTokens.Typography.compactCardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMildLight)

                Text("\(vendor) · \(model)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if lastSeenEnabled {
                    Text(lastSeenCaption)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: DesignTokens.Spacing.sm)

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
                statusPill
                Text("\(linkQualityTitle) LQI")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    private var identityRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
                hasUpdate: state.hasUpdateAvailable,
                otaStatus: otaStatus,
                size: DesignTokens.Size.deviceCardImage * 0.80
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                nameView

                deviceMetadata
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: DesignTokens.Spacing.sm)

            if lastSeenEnabled, state.lastSeen != nil {
                lastSeenBadge
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading),
                GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: DesignTokens.Spacing.xl
        ) {
            identityMetric(label: "Type", icon: "network", value: device.type.chipLabel, unit: nil, color: deviceTypeColor)
            identityMetric(label: "Status", icon: statusIcon, value: statusTitle, unit: nil, color: statusColor)
            identityMetric(label: "Signal", icon: "wifi", value: linkQualityTitle, unit: linkQualityTitle == "—" ? nil : "LQI", color: lqiValueColor)
            identityMetric(label: "Power", icon: powerIcon, value: powerTitle, unit: nil, color: powerColor)
        }
    }

    private func identityMetric(label: String, icon: String, value: String, unit: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(DesignTokens.Typography.identityTileValue)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorTight)
                if let unit {
                    Text(unit)
                        .font(DesignTokens.Typography.identityTileUnit)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastSeenBadge: some View {
        Text(lastSeenValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .padding(.top, DesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private var nameView: some View {
        let label = Text(device.friendlyName)
            .font(DesignTokens.Typography.cardTitle)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(DesignTokens.Typography.scaleFactorAggressive)
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

    private var deviceMetadata: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(vendor)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorSubtle)

            Text(model)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMildLight)
        }
    }

    private var statusPill: some View {
        Text(statusTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(statusColor.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
            .frame(height: DesignTokens.Size.hairline)
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

    private var vendor: String {
        device.definition?.vendor ?? device.manufacturer ?? "Unknown Vendor"
    }

    private var model: String {
        device.definition?.model ?? device.modelId ?? "Unknown Model"
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
            return "Availability off"
        }

        return isAvailable ? "Online" : "Offline"
    }

    private var statusColor: Color {
        if otaStatus?.isActive == true { return .blue }
        if device.interviewing { return .orange }
        if !device.availabilityTrackingEnabled { return .secondary }
        return isAvailable ? .green : .red
    }

    private var statusIcon: String {
        if otaStatus?.isActive == true { return "arrow.triangle.2.circlepath.circle.fill" }
        if device.interviewing { return "dot.radiowaves.left.and.right" }
        if !device.availabilityTrackingEnabled { return "minus.circle.fill" }
        return isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill"
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

    private var powerTitle: String {
        if device.type == .endDevice, let battery = state.battery {
            return "\(battery)%"
        }
        return normalizedPowerSource
    }

    private var powerColor: Color {
        if device.type == .endDevice, let battery = state.battery {
            return battery.batteryColor
        }
        return .secondary
    }

    private var powerIcon: String {
        if device.type == .endDevice {
            return (state.battery ?? 100) <= DesignTokens.Threshold.lowBattery ? "battery.25" : "battery.100"
        }
        return "powerplug.fill"
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

    private var lastSeenValue: String {
        guard let lastSeen = state.lastSeen else { return "—" }
        return DeviceCardLastSeen.format(lastSeen: lastSeen)
    }

    private var lastSeenCaption: String {
        guard lastSeenValue != "—" else { return "Last seen unknown" }
        return "Last seen \(lastSeenValue)"
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
    VStack(spacing: DesignTokens.Spacing.xl) {
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
        DeviceCard(
            device: .preview,
            state: ["linkquality": .int(96)],
            isAvailable: true,
            otaStatus: nil,
            displayMode: .compact
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
