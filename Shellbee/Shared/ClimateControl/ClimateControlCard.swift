import SwiftUI

struct ClimateControlCard: View {
    let context: ClimateControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var setpointDraft: Double

    init(context: ClimateControlContext, mode: CardDisplayMode, onSend: @escaping (JSONValue) -> Void = { _ in }) {
        self.context = context
        self.mode = mode
        self.onSend = onSend
        _setpointDraft = State(initialValue: context.activeSetpoint ?? 20)
    }

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CardHeader(
                    systemImage: heroIcon,
                    title: "Climate",
                    value: context.runningStateLabel,
                    tint: heroTint,
                    valueColor: isActive ? heroTint : .secondary
                )
                temperatureRow
                if showsSetpointControl { setpointSlider }
                if let modes = context.systemModeFeature?.values, !modes.isEmpty,
                   mode == .interactive, context.systemModeFeature?.isWritable == true {
                    modePicker(modes: modes)
                }
            }
            .cardSurface()
            .onChange(of: context.activeSetpoint) { _, v in setpointDraft = v ?? setpointDraft }
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Mode glyph (flame/snowflake/fan) +
    /// "Climate" + temp · target summary + running-state pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: heroIcon,
                title: "Climate",
                subtitle: snapshotSecondaryText,
                tint: heroTint
            ) {
                Text(context.runningStateLabel.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? heroTint : Color(.secondaryLabel))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        isActive ? heroTint.opacity(DesignTokens.Opacity.chipFill)
                                 : Color(.tertiarySystemFill),
                        in: Capsule()
                    )
            }
        }
    }

    private var snapshotSecondaryText: String {
        var parts: [String] = [context.displayTemperature]
        if let setpoint = context.activeSetpoint {
            parts.append("Target \(formatTemp(setpoint))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Tinting

    /// State-derived hue for the gradient, eyebrow, target text and controls.
    /// Heating → orange (warm), Cooling → blue (cold), Fan only → teal,
    /// Idle/off → neutral grey so the card recedes when nothing's happening.
    private var heroTint: Color {
        switch runningKey {
        case "heat", "heating": return .orange
        case "cool", "cooling": return .blue
        case "fan", "fan_only": return .teal
        default: return Color(.tertiaryLabel)
        }
    }

    private var runningKey: String {
        (context.runningState ?? context.systemMode ?? "").lowercased()
    }

    private var isActive: Bool {
        heroTint != Color(.tertiaryLabel)
    }

    private var heroIcon: String {
        switch runningKey {
        case "heat", "heating": return "flame.fill"
        case "cool", "cooling": return "snowflake"
        case "fan", "fan_only": return "fan.fill"
        default: return "thermometer.medium"
        }
    }

    private var temperatureRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(context.displayTemperature)
                .font(DesignTokens.Typography.climateTemperature)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
            if context.activeSetpoint != nil {
                Text("Target \(formatTemp(setpointDraft))")
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: setpointDraft))
                    .animation(.snappy, value: setpointDraft)
            }
        }
    }

    private func formatTemp(_ v: Double) -> String {
        String(format: "%.1f°", v)
    }

    // MARK: - Setpoint row

    private var showsSetpointControl: Bool {
        mode == .interactive
            && context.activeSetpointFeature?.isWritable == true
            && context.activeSetpoint != nil
    }

    /// Target temperature on a slider over the device's own range. The
    /// value commits when the drag ends, so one message goes out per change.
    private var setpointSlider: some View {
        let feature = context.activeSetpointFeature
        let range = feature?.range ?? 5...35
        return Slider(
            value: $setpointDraft,
            in: range,
            step: feature?.step ?? 0.5,
            onEditingChanged: { editing in
                guard !editing, let p = context.setpointPayload(setpointDraft) else { return }
                onSend(p)
            }
        )
        .tint(isActive ? heroTint : .orange)
        .accessibilityLabel("Target")
        .accessibilityValue(formatTemp(setpointDraft))
    }

    // MARK: - Mode

    /// Segmented for up to four modes, a menu picker beyond that.
    @ViewBuilder
    private func modePicker(modes: [String]) -> some View {
        let selection = Binding<String>(
            get: { context.systemMode ?? "" },
            set: { m in if let p = context.systemModePayload(m) { onSend(p) } }
        )
        if modes.count <= DesignTokens.Count.segmentedMaxOptions {
            Picker("Mode", selection: selection) {
                ForEach(modes, id: \.self) { Text(displayLabel(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
        } else {
            HStack {
                Text("Mode")
                Spacer()
                Picker("Mode", selection: selection) {
                    ForEach(modes, id: \.self) { Text(displayLabel(for: $0)).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.secondary)
            }
        }
    }

    private func displayLabel(for mode: String) -> String {
        mode.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = ClimateControlContext(device: .preview, state: [
                "local_temperature": .double(21.3),
                "occupied_heating_setpoint": .double(22.0),
                "system_mode": .string("heat"),
                "running_state": .string("heating")
            ]) {
                ClimateControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                ClimateControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
            if let cool = ClimateControlContext(device: .preview, state: [
                "local_temperature": .double(24.8),
                "occupied_cooling_setpoint": .double(22.0),
                "system_mode": .string("cool"),
                "running_state": .string("cooling")
            ]) {
                ClimateControlCard(context: cool, mode: .interactive, onSend: { _ in })
            }
            if let idle = ClimateControlContext(device: .preview, state: [
                "local_temperature": .double(20.5),
                "occupied_heating_setpoint": .double(20.0),
                "system_mode": .string("auto"),
                "running_state": .string("idle")
            ]) {
                ClimateControlCard(context: idle, mode: .interactive, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
