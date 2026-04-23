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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            hero
            if mode == .interactive, context.activeSetpointFeature?.isWritable == true {
                setpointControl
            }
            if mode == .interactive, let modes = context.systemModeFeature?.values, !modes.isEmpty {
                modeControl(modes: modes)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .onChange(of: context.activeSetpoint) { _, v in setpointDraft = v ?? setpointDraft }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: headerIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(context.runningStateColor)
                .frame(width: 36, height: 36)
                .background(
                    context.runningStateColor.opacity(DesignTokens.Opacity.chipFill),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Climate")
                    .font(.headline)
                if context.runningState != nil {
                    Text(context.runningStateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var headerIcon: String {
        switch context.runningState?.lowercased() {
        case "heat", "heating": return "flame.fill"
        case "cool", "cooling": return "snowflake"
        case "fan", "fan_only": return "fan.fill"
        default: return "thermometer.medium"
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.displayTemperature)
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .monospacedDigit()
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let setpoint = context.activeSetpoint {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f°", setpoint))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(context.runningStateColor)
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Setpoint control

    private var setpointControl: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            setpointButton(systemImage: "minus") {
                let step = context.activeSetpointFeature?.step ?? 0.5
                let lo = context.activeSetpointFeature?.range?.lowerBound ?? 5
                setpointDraft = max(lo, setpointDraft - step)
                if let p = context.setpointPayload(setpointDraft) { onSend(p) }
            }

            Text(String(format: "%.1f°", setpointDraft))
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText(value: setpointDraft))
                .animation(.snappy, value: setpointDraft)

            setpointButton(systemImage: "plus") {
                let step = context.activeSetpointFeature?.step ?? 0.5
                let hi = context.activeSetpointFeature?.range?.upperBound ?? 35
                setpointDraft = Swift.min(hi, setpointDraft + step)
                if let p = context.setpointPayload(setpointDraft) { onSend(p) }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func setpointButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Color(.systemBackground), in: Circle())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode control

    @ViewBuilder
    private func modeControl(modes: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Mode")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if modes.count <= 4 {
                Picker("Mode", selection: modeBinding) {
                    ForEach(modes, id: \.self) { m in
                        Text(displayLabel(for: m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(modes, id: \.self) { m in
                            let isSelected = context.systemMode == m
                            Button {
                                if let p = context.systemModePayload(m) { onSend(p) }
                            } label: {
                                Text(displayLabel(for: m))
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                                    .padding(.vertical, DesignTokens.Spacing.sm)
                                    .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var modeBinding: Binding<String> {
        Binding(
            get: { context.systemMode ?? "" },
            set: { new in
                if let p = context.systemModePayload(new) { onSend(p) }
            }
        )
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
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
