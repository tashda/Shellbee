import SwiftUI

struct SwitchControlCard: View {
    let context: SwitchControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            heroHeadline
            if context.hasPowerMetering {
                hairline
                meteringGrid
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    /// Single state-derived color for the gradient, eyebrow, value and toggle.
    /// Green when on (Apple Home outlet/switch tile convention); neutral grey
    /// when off so the card recedes.
    private var heroTint: Color {
        context.isOn ? .green : Color(.tertiaryLabel)
    }

    private var heroBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [
                    heroTint.opacity(context.isOn ? 0.18 : 0.06),
                    heroTint.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Hero

    private var heroHeadline: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                heroEyebrow
                heroValue
            }
            Spacer(minLength: 0)
            powerControl
        }
    }

    private var heroEyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: context.isOn ? "power.circle.fill" : "power.circle")
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text(eyebrowLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(heroTint)
    }

    private var eyebrowLabel: String {
        if let endpoint = context.endpointLabel { return "Switch · \(endpoint)" }
        return "Switch"
    }

    private var heroValue: some View {
        Text(context.isOn ? "On" : "Off")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(heroTint)
    }

    @ViewBuilder
    private var powerControl: some View {
        if mode == .interactive, let f = context.stateFeature, f.isWritable {
            Toggle("", isOn: Binding(
                get: { context.isOn },
                set: { _ in if let p = context.togglePayload() { onSend(p) } }
            ))
            .labelsHidden()
            .tint(toggleTint)
        } else {
            statePill
        }
    }

    /// Toggle stays green even when off so it reads as "tap to turn on";
    /// disabled grey would make it look unavailable.
    private var toggleTint: Color {
        context.isOn ? .green : .green
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

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Metering grid

    private var meteringGrid: some View {
        let tiles = meteringTiles
        let columns = Array(repeating: GridItem(.flexible(),
                                                spacing: DesignTokens.Spacing.lg,
                                                alignment: .topLeading),
                            count: min(tiles.count, 2))
        return LazyVGrid(columns: columns,
                         alignment: .leading,
                         spacing: DesignTokens.Spacing.xl) {
            ForEach(tiles, id: \.label) { tile in
                MeteringTile(label: tile.label, value: tile.value, unit: tile.unit, icon: tile.icon)
            }
        }
    }

    private var meteringTiles: [MeteringDescriptor] {
        var tiles: [MeteringDescriptor] = []
        if let v = context.powerValue {
            tiles.append(.init(label: "Power", icon: "bolt.fill",
                               value: format(v, fraction: 1), unit: context.powerFeature?.unit ?? "W"))
        }
        if let v = context.energyValue {
            tiles.append(.init(label: "Energy", icon: "leaf.fill",
                               value: format(v, fraction: 2), unit: context.energyFeature?.unit ?? "kWh"))
        }
        if let v = context.voltageValue {
            tiles.append(.init(label: "Voltage", icon: "bolt",
                               value: format(v, fraction: 0), unit: context.voltageFeature?.unit ?? "V"))
        }
        if let v = context.currentValue {
            tiles.append(.init(label: "Current", icon: "bolt.ring.closed",
                               value: format(v, fraction: 2), unit: context.currentFeature?.unit ?? "A"))
        }
        return tiles
    }

    private func format(_ v: Double, fraction: Int) -> String {
        v.formatted(.number.precision(.fractionLength(0...fraction)))
    }
}

// MARK: - Metering tile

private struct MeteringDescriptor {
    let label: String
    let icon: String
    let value: String
    let unit: String
}

private struct MeteringTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(unit)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
