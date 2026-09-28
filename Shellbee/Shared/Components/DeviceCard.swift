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
                tiles: tiles,
                renameAccessibilityLabel: "Rename device",
                onRenameTapped: onRenameTapped,
                onNameHiddenChange: onNameHiddenChange
            ) {
                image(size: DesignTokens.Size.identityHeroImage)
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

    // MARK: - Tiles

    private var tiles: [IdentityTile] {
        var tiles = [statusTile]
        if let lqi = state.linkQuality {
            let weak = lqi < DesignTokens.Threshold.weakSignal
            tiles.append(IdentityTile(
                value: "\(lqi)",
                caption: "Signal",
                systemImage: "cellularbars",
                symbolVariableValue: Double(lqi) / DesignTokens.Threshold.maxLinkQuality,
                color: weak ? .orange : nil
            ))
        }
        tiles.append(powerTile)
        tiles.append(IdentityTile(value: device.type.chipLabel, caption: "Role", systemImage: roleSymbol))
        return tiles
    }

    /// Online or offline, with how long ago the device last reported.
    private var statusTile: IdentityTile {
        let since = lastSeenEnabled ? DeviceStatus.lastSeenText(state.lastSeen) : nil
        return IdentityTile(
            value: status.title,
            caption: since.map { "Seen \($0.lowercased())" } ?? "Status",
            dotColor: status.color,
            color: status.needsAttention ? status.color : nil
        )
    }

    private var powerTile: IdentityTile {
        if let battery = state.battery {
            let low = DesignTokens.Threshold.isLowBattery(battery)
            return IdentityTile(value: "\(battery) %", caption: "Battery",
                                systemImage: low ? "battery.25percent" : "battery.100percent",
                                color: low ? .red : nil)
        }
        return IdentityTile(value: normalizedPowerSource, caption: "Power", systemImage: "powerplug")
    }

    private var roleSymbol: String {
        switch device.type {
        case .router: "point.3.connected.trianglepath.dotted"
        case .coordinator: "antenna.radiowaves.left.and.right"
        default: "dot.radiowaves.right"
        }
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
        .tint(.accentColor)
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
