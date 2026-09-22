import SwiftUI

struct RemoteCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode

    private var lastAction: String? {
        guard let s = state["action"]?.stringValue, !s.isEmpty else { return nil }
        return s
    }

    private var voltage: Double? { state["voltage"]?.numberValue }

    private var voltageUnit: String {
        let flat = (device.definition?.exposes ?? []).flatMap { [$0] + ($0.features ?? []) }
        return flat.first(where: { $0.name == "voltage" || $0.property == "voltage" })?.unit ?? "mV"
    }

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CardHeader(systemImage: "hand.tap.fill", title: "Remote", tint: .purple)
                HStack(spacing: DesignTokens.Spacing.md) {
                    ActivityInstrumentView(
                        instrument: ActivityInstrument(kind: .action, severity: lastAction == nil ? .quiet : .routine),
                        size: DesignTokens.Size.remoteInstrument
                    )
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(lastAction.map(prettyAction) ?? "Waiting for a press")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(lastAction == nil ? .secondary : .primary)
                            .lineLimit(2)
                            .contentTransition(.opacity)
                        if lastAction != nil, let pressed = DeviceStatus.lastSeenText(state.lastSeen) {
                            Text("Pressed \(pressed)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let voltage {
                    StatStrip(items: [StatStripItem(value: "\(Int(voltage)) \(voltageUnit)", caption: "Voltage")])
                }
            }
            .cardSurface()
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Command glyph + "Remote" + last action
    /// (and voltage when present).
    private var snapshotContent: some View {
        CompactSnapshotCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "command")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let secondary = snapshotSecondaryText {
                        Text(secondary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Waiting")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.sm)
            }
        }
    }

    private var snapshotSecondaryText: String? {
        var parts: [String] = []
        if let action = lastAction { parts.append(prettyAction(action)) }
        if let v = voltage { parts.append("\(Int(v)) \(voltageUnit)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func prettyAction(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            RemoteCard(device: .preview, state: [
                "action": .string("1_short_release"),
                "voltage": .double(1500)
            ], mode: .interactive)
            RemoteCard(device: .preview, state: [
                "action": .string("brightness_up_click"),
                "voltage": .double(1200)
            ], mode: .snapshot)
            RemoteCard(device: .preview, state: [:], mode: .interactive)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
