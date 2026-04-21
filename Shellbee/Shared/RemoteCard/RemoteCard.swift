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
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(DesignTokens.Spacing.lg)

            actionSection
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.lg)

            if let voltage {
                Divider()
                    .padding(.leading, DesignTokens.Spacing.lg)
                voltageRow(voltage)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }

            if mode == .interactive {
                Divider()
                    .padding(.leading, DesignTokens.Spacing.lg)
                Text("This remote sends commands directly — no actions to send from here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: "remote")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Remote State").font(.headline)
            } else {
                Text("Remote").font(.headline)
            }
        }
    }

    // MARK: – Action

    @ViewBuilder
    private var actionSection: some View {
        if let action = lastAction {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 32, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.body.weight(.semibold))
                    Text("Last action")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 32, alignment: .center)
                Text("No actions received yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: – Voltage

    private func voltageRow(_ value: Double) -> some View {
        HStack {
            Label {
                Text("Battery Voltage")
            } icon: {
                Image(systemName: "bolt")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(value)) \(voltageUnit)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            RemoteCard(device: .preview, state: [
                "action": .string("1_short_release"),
                "battery": .double(100),
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
