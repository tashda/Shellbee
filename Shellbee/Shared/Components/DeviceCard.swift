import SwiftUI

enum DeviceIdentityDisplayMode {
    case prominent
    case compact
}

/// A device's identity: the centred hero on Device detail (`.prominent`)
/// or a Settings-style row where the device is linked from elsewhere
/// (`.compact`).
struct DeviceCard: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var bridgeID: UUID? = nil
    /// Only set when more than one bridge is saved; see
    /// `AppEnvironment.attributionBridgeName(for:)`.
    var bridgeName: String? = nil
    var bridgeAttributionStyle: BridgeAttributionStyle = .badge
    var lastSeenEnabled: Bool = true
    var onRenameTapped: (() -> Void)? = nil
    var onNameHiddenChange: ((Bool) -> Void)? = nil
    var displayMode: DeviceIdentityDisplayMode = .prominent

    private var status: DeviceStatus {
        DeviceStatus(device: device, isAvailable: isAvailable, otaStatus: otaStatus)
    }

    private var transferPayload: DeviceTransferPayload {
        DeviceTransferPayload(device: device, bridgeID: bridgeID, bridgeName: bridgeName)
    }

    var body: some View {
        SwiftUI.Group {
            switch displayMode {
            case .prominent: hero
            case .compact: row
            }
        }
        .draggable(transferPayload) {
            DeviceTransferPreview(device: device, isAvailable: isAvailable, otaStatus: otaStatus)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = transferPayload.plainText
            } label: {
                Label("Copy Device Information", systemImage: "doc.on.doc")
            }
        }
        .accessibilityAction(named: "Copy Device Information") {
            UIPasteboard.general.string = transferPayload.plainText
        }
    }

    private var hero: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            IdentityHero(
                name: device.friendlyName,
                subtitle: device.cardSubtitle,
                bridgeID: bridgeID,
                bridgeName: bridgeName,
                chips: chips,
                renameAccessibilityLabel: "Rename device",
                onRenameTapped: onRenameTapped,
                onNameHiddenChange: onNameHiddenChange
            ) {
                image(size: DesignTokens.Size.deviceHeroImage)
            }

            if let otaStatus, otaStatus.isActive {
                otaProgress(status: otaStatus)
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Duration.fastFade), value: otaStatus?.isActive == true)
    }

    private var row: some View {
        IdentityRow(
            name: device.friendlyName,
            subtitle: device.cardSubtitle,
            bridgeID: bridgeID,
            bridgeName: bridgeName,
            bridgeAttributionStyle: bridgeAttributionStyle,
            status: status,
            isListRow: true
        ) {
            image(size: DesignTokens.Size.deviceRowImage)
        }
    }

    private func image(size: CGFloat) -> some View {
        DeviceImageView(
            device: device,
            isAvailable: isAvailable,
            hasUpdate: state.hasUpdateAvailable,
            otaStatus: otaStatus,
            size: size,
            showsAvailabilityIndicator: false
        )
    }

    // MARK: - Chips

    private var chips: [IdentityChip] {
        var chips = [
            IdentityChip(title: statusTitle, dotColor: status.color),
            IdentityChip(title: device.type.chipLabel),
        ]
        if let lqi = state.linkQuality {
            chips.append(IdentityChip(
                title: "\(lqi)",
                systemImage: "cellularbars",
                symbolVariableValue: Double(lqi) / DesignTokens.Threshold.maxLinkQuality
            ))
        }
        chips.append(powerChip)
        return chips
    }

    private var powerChip: IdentityChip {
        if device.type == .endDevice, let battery = state.battery {
            let low = DesignTokens.Threshold.isLowBattery(battery)
            return IdentityChip(title: "\(battery) %",
                                systemImage: low ? "battery.25percent" : "battery.100percent",
                                color: low ? .red : nil)
        }
        return IdentityChip(title: normalizedPowerSource)
    }

    private var normalizedPowerSource: String {
        let source = state["power_source"]?.stringValue ?? device.powerSource
        let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "Unknown power" }
        let normalized = trimmed.lowercased()
        if normalized.contains("battery") { return "Battery" }
        if normalized.contains("mains") || normalized.contains("ac") || normalized.contains("dc") { return "Mains" }
        return trimmed.capitalized
    }

    /// A healthy device doesn't need its last-seen time; an offline one
    /// says how long it has been gone ("Offline · 3 h ago").
    private var statusTitle: String {
        guard status.needsAttention, !isAvailable, lastSeenEnabled,
              let since = DeviceStatus.lastSeenText(state.lastSeen) else { return status.title }
        return "\(status.title) · \(since)"
    }

    // MARK: - OTA

    private func otaProgress(status: OTAUpdateStatus) -> some View {
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
                ProgressView().progressViewStyle(.linear)
            }
        }
        .tint(.blue)
        .cardSurface(padding: DesignTokens.Spacing.md)
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
    List {
        DeviceCard(
            device: .preview,
            state: ["linkquality": .int(96), "battery": .int(12)],
            isAvailable: false,
            otaStatus: nil
        )
        .listRowBackground(Color.clear)
        DeviceCard(
            device: .preview,
            state: ["linkquality": .int(96)],
            isAvailable: true,
            otaStatus: nil,
            displayMode: .compact
        )
        .listRowBackground(Color.clear)
    }
}
