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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                heroHeadline
                if showsSetpointControl {
                    hairline
                    setpointRow
                }
                if let modes = context.systemModeFeature?.values, !modes.isEmpty, mode == .interactive {
                    hairline
                    modeRow(modes: modes)
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heroBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                    radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
            .onChange(of: context.activeSetpoint) { _, v in setpointDraft = v ?? setpointDraft }
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Mode glyph (flame/snowflake/fan) +
    /// "Climate" + temp · target summary + running-state pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: heroIcon)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(heroTint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Climate")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(snapshotSecondaryText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

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

    private var heroBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [heroTint.opacity(isActive ? 0.18 : 0.06),
                         heroTint.opacity(DesignTokens.Opacity.subtleFade)],
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
        }
    }

    private var heroEyebrow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: heroIcon)
                .font(DesignTokens.Typography.eyebrowIcon)
                .symbolRenderingMode(.hierarchical)
            Text(context.runningStateLabel)
                .font(DesignTokens.Typography.eyebrowLabel)
                .tracking(DesignTokens.Typography.eyebrowTracking)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(heroTint)
    }

    private var heroIcon: String {
        switch runningKey {
        case "heat", "heating": return "flame.fill"
        case "cool", "cooling": return "snowflake"
        case "fan", "fan_only": return "fan.fill"
        default: return "thermometer.medium"
        }
    }

    @ViewBuilder
    private var heroValue: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(context.displayTemperature)
                .font(DesignTokens.Typography.heroValue)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
            // In snapshot mode (and when no interactive setpoint control is
            // shown), surface the target inside the hero block — otherwise the
            // setpoint row below already carries it.
            if let setpoint = context.activeSetpoint, !showsSetpointControl {
                Text("Target \(formatTemp(setpoint))")
                    .font(DesignTokens.Typography.heroSubtitle)
                    .foregroundStyle(heroTint)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorRelaxed)
            }
        }
    }

    private func formatTemp(_ v: Double) -> String {
        String(format: "%.1f°", v)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
            .frame(height: DesignTokens.Size.hairline)
    }

    // MARK: - Setpoint row

    private var showsSetpointControl: Bool {
        mode == .interactive
            && context.activeSetpointFeature?.isWritable == true
            && context.activeSetpoint != nil
    }

    private var setpointRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "target")
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text("Target")
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.md) {
                setpointButton(systemImage: "minus") {
                    let step = context.activeSetpointFeature?.step ?? 0.5
                    let lo = context.activeSetpointFeature?.range?.lowerBound ?? 5
                    setpointDraft = max(lo, setpointDraft - step)
                    if let p = context.setpointPayload(setpointDraft) { onSend(p) }
                }

                Text(formatTemp(setpointDraft))
                    .font(DesignTokens.Typography.identityTileValue)
                    .monospacedDigit()
                    .foregroundStyle(heroTint)
                    .frame(minWidth: DesignTokens.Size.climateSetpointMinWidth)
                    .contentTransition(.numericText(value: setpointDraft))
                    .animation(.snappy, value: setpointDraft)

                setpointButton(systemImage: "plus") {
                    let step = context.activeSetpointFeature?.step ?? 0.5
                    let hi = context.activeSetpointFeature?.range?.upperBound ?? 35
                    setpointDraft = Swift.min(hi, setpointDraft + step)
                    if let p = context.setpointPayload(setpointDraft) { onSend(p) }
                }
            }
        }
    }

    private func setpointButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.climateActionIcon)
                .foregroundStyle(heroTint)
                .frame(width: DesignTokens.Size.climateActionButton, height: DesignTokens.Size.climateActionButton)
                .background(heroTint.opacity(DesignTokens.Opacity.actionButtonFill), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode row

    @ViewBuilder
    private func modeRow(modes: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "dial.medium")
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text("Mode")
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(modes, id: \.self) { m in
                        modeChip(m)
                    }
                }
            }
        }
    }

    private func modeChip(_ m: String) -> some View {
        let isSelected = context.systemMode == m
        let chipTint = chipColor(for: m)
        return Button {
            if let p = context.systemModePayload(m) { onSend(p) }
        } label: {
            Text(displayLabel(for: m))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    isSelected ? chipTint.opacity(DesignTokens.Opacity.strongAccentFill) : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? chipTint : Color.primary)
        }
        .buttonStyle(.plain)
    }

    /// Chip tint follows the *mode's* meaning, not the live running state —
    /// "Heat" stays orange even when the system is currently idle, so the
    /// selector reads as a legend not just a tint accent.
    private func chipColor(for mode: String) -> Color {
        switch mode.lowercased() {
        case "heat", "heating", "emergency_heating": return .orange
        case "cool", "cooling": return .blue
        case "fan_only", "fan": return .teal
        case "auto": return .purple
        case "dry": return .yellow
        case "off": return Color(.tertiaryLabel)
        default: return .accentColor
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
