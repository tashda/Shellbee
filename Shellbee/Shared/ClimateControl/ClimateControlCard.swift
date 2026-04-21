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
            if mode == .interactive { interactiveContent } else { snapshotContent }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        .onChange(of: context.activeSetpoint) { _, v in setpointDraft = v ?? setpointDraft }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.runningStateColor)
                Text("Climate State").font(.headline)
            } else {
                Text("Climate").font(.headline)
            }
            Spacer()
            if let state = context.runningState {
                Text(context.runningStateLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.runningStateColor)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(context.runningStateColor.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
                    .opacity(state.lowercased() == "idle" ? 0.5 : 1)
            }
        }
    }

    @ViewBuilder private var interactiveContent: some View {
        temperatureDisplay
        if context.activeSetpointFeature != nil { setpointControl }
        if let modes = context.systemModeFeature?.values, !modes.isEmpty { modeControl(modes: modes) }
    }

    @ViewBuilder private var snapshotContent: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            temperatureTile("Current", context.displayTemperature)
            if let setpoint = context.activeSetpoint {
                temperatureTile("Set to", String(format: "%.1f°", setpoint))
            }
            if let mode = context.systemMode {
                temperatureTile("Mode", mode.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }
    }

    private var temperatureDisplay: some View {
        HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Spacing.xs) {
            Text(context.displayTemperature)
                .font(.system(size: 52, weight: .thin, design: .rounded))
            Spacer()
            if let setpoint = context.activeSetpoint {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Set to").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", setpoint))
                        .font(.title2.weight(.semibold))
                }
            }
        }
    }

    private var setpointControl: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button {
                let step = context.activeSetpointFeature?.step ?? 0.5
                let min = context.activeSetpointFeature?.range?.lowerBound ?? 5
                setpointDraft = max(min, setpointDraft - step)
                if let p = context.setpointPayload(setpointDraft) { onSend(p) }
            } label: {
                Image(systemName: "minus").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            Text(String(format: "%.1f°", setpointDraft))
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity)
            Button {
                let step = context.activeSetpointFeature?.step ?? 0.5
                let max = context.activeSetpointFeature?.range?.upperBound ?? 35
                setpointDraft = Swift.min(max, setpointDraft + step)
                if let p = context.setpointPayload(setpointDraft) { onSend(p) }
            } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func modeControl(modes: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(modes, id: \.self) { m in
                    let isSelected = context.systemMode == m
                    Button {
                        if let p = context.systemModePayload(m) { onSend(p) }
                    } label: {
                        Text(m.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func temperatureTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
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
