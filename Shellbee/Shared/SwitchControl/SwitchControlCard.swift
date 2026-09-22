import SwiftUI

struct SwitchControlCard: View {
    let context: SwitchControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CardHeader(
                    systemImage: "power",
                    title: eyebrowLabel,
                    value: context.isOn ? "On" : "Off",
                    tint: heroTint
                ) {
                    powerControl
                }
            }
            .cardSurface()
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Power glyph, "Switch" + endpoint,
    /// optional power-metering summary, ON/OFF pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: context.isOn ? "power.circle.fill" : "power.circle",
                title: eyebrowLabel,
                subtitle: snapshotSecondaryText,
                tint: heroTint
            ) {
                statePill
            }
        }
    }

    /// Power-metering summary if the payload carries it — otherwise nil
    /// (collapsed to a single line). Power is the headline number; voltage
    /// joins it when present.
    private var snapshotSecondaryText: String? {
        var parts: [String] = []
        if let p = context.powerValue {
            parts.append("\(format(p, fraction: 1)) \(context.powerFeature?.unit ?? "W")")
        }
        if let v = context.voltageValue {
            parts.append("\(format(v, fraction: 0)) \(context.voltageFeature?.unit ?? "V")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Single state-derived color for the gradient, eyebrow, value and toggle.
    /// Green when on (Apple Home outlet/switch tile convention); neutral grey
    /// when off so the card recedes.
    private var heroTint: Color {
        context.isOn ? .green : Color(.tertiaryLabel)
    }

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Switch · \(endpoint)" }
        return "Switch"
    }

    @ViewBuilder
    private var powerControl: some View {
        if mode == .interactive, let f = context.stateFeature, f.isWritable {
            Toggle("", isOn: Binding(
                get: { context.isOn },
                set: { _ in if let p = context.togglePayload() { onSend(p) } }
            ))
            .labelsHidden()
            .tint(.green)
        }
    }

    private var statePill: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? Color.green : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? Color.green.opacity(DesignTokens.Opacity.chipFill)
                             : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    private func format(_ v: Double, fraction: Int) -> String {
        v.formatted(.number.precision(.fractionLength(0...fraction)))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = SwitchControlContext(device: .preview, state: [
                "state": .string("ON"),
                "power": .double(42.5),
                "energy": .double(1.23),
                "voltage": .double(231),
                "current": .double(0.18)
            ]) {
                SwitchControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                SwitchControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
            if let off = SwitchControlContext(device: .preview, state: [
                "state": .string("OFF")
            ]) {
                SwitchControlCard(context: off, mode: .interactive, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
