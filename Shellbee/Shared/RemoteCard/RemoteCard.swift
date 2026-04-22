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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            actionSection
            if let voltage {
                voltageRow(voltage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: "command")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(mode == .snapshot ? "Remote State" : "Remote")
                .font(.headline)
        }
    }

    // MARK: – Action

    @ViewBuilder
    private var actionSection: some View {
        if let action = lastAction {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("Last action")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            Text("Waiting for actions")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: – Voltage

    private func voltageRow(_ value: Double) -> some View {
        HStack {
            Image(systemName: "bolt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Voltage")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(value)) \(voltageUnit)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
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
