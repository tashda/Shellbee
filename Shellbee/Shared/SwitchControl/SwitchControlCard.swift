import SwiftUI

struct SwitchControlCard: View {
    let context: SwitchControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            if context.hasPowerMetering { metricsRow }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: context.isOn ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.isOn ? Color.green : Color(.tertiaryLabel))
                Text("Switch State").font(.headline)
            } else {
                Text("Switch").font(.headline)
            }
            Spacer()
            if mode == .interactive, let f = context.stateFeature, f.isWritable {
                Toggle("", isOn: Binding(
                    get: { context.isOn },
                    set: { _ in if let p = context.togglePayload() { onSend(p) } }
                ))
                .labelsHidden()
            } else {
                stateBadge
            }
        }
    }

    private var stateBadge: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? Color.green : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? Color.green.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    private var metricsRow: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            if let v = context.powerValue   { metricTile(String(format: "%.1f W", v),   "Power") }
            if let v = context.energyValue  { metricTile(String(format: "%.2f kWh", v), "Energy") }
            if let v = context.voltageValue { metricTile(String(format: "%.0f V", v),   "Voltage") }
            if let v = context.currentValue { metricTile(String(format: "%.2f A", v),   "Current") }
        }
    }

    private func metricTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = SwitchControlContext(device: .preview, state: [
                "state": .string("ON"), "power": .double(42.5), "energy": .double(1.23)
            ]) {
                SwitchControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                SwitchControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
