import SwiftUI

struct FanControlCard: View {
    let context: FanControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var speedDraft: Double = 0

    private var air: FanAirReadings { FanAirReadings(context: context) }
    private var hasAirSensors: Bool { air.hasAirSensors }

    /// The controls only: power, mode and speed. Air readings and filter
    /// health are rows beneath it (`FanReadingsSections`).
    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            heroCard
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Shared CompactSnapshotCard chrome,
    /// single row: fan glyph, "Fan", speed/mode summary, ON/OFF pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: hasAirSensors ? "aqi.medium" : (context.isOn ? "fan.fill" : "fan"))
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(heroTint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasAirSensors ? "Air Quality" : "Fan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let secondary = snapshotSecondaryText {
                        Text(secondary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                statePill
            }
        }
    }

    /// Best one-line summary for the current state. Air-quality fans get
    /// the AQ reading; plain fans get speed or mode if available.
    private var snapshotSecondaryText: String? {
        if hasAirSensors {
            var parts: [String] = []
            if let pm = air.pm25 { parts.append("\(Int(pm.rounded())) \(air.pm25Unit)") }
            if let aq = air.airQuality { parts.append(prettify(aq)) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        guard context.isOn else { return nil }
        if let modeName = context.fanModeFeature?.property,
           let mode = context.state[modeName]?.stringValue, !mode.isEmpty {
            return prettify(mode)
        }
        if let speedProp = context.speedFeature?.property,
           let speed = context.state[speedProp]?.numberValue {
            return "Speed \(Int(speed))"
        }
        return nil
    }

    /// The single state-derived color that drives the hero gradient, eyebrow,
    /// and any state-text inside the hero. Air-quality devices use an AQI
    /// scale; plain fans use teal when on, neutral when off.
    private var heroTint: Color {
        if hasAirSensors { return air.airQualityTint }
        return context.isOn ? .teal : Color(.tertiaryLabel)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(
                systemImage: hasAirSensors ? "aqi.medium" : (context.isOn ? "fan.fill" : "fan"),
                title: hasAirSensors ? "Air Purifier" : "Fan",
                value: headerValue,
                tint: heroTint
            ) {
                powerControl
            }
            if hasModeControl { modeControl }
            if hasSpeedControl { speedControl }
        }
        .cardSurface()
    }

    /// "On · Speed 3", "Off", or for purifiers without a power state the
    /// air quality in words.
    private var headerValue: String {
        guard context.stateFeature != nil else { return air.airQuality.map(prettify) ?? "" }
        guard context.isOn else { return "Off" }
        if hasSpeedControl, !hasAirSensors { return "On · Speed \(Int(speedDraft.rounded()))" }
        return "On"
    }

    @ViewBuilder
    private var powerControl: some View {
        if mode == .interactive, let f = context.stateFeature, f.isWritable {
            Toggle("", isOn: Binding(
                get: { context.isOn },
                set: { _ in if let p = context.togglePayload() { onSend(p) } }
            ))
            .labelsHidden()
            .tint(.teal)
        }
    }

    private var statePill: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? heroTint : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? heroTint.opacity(DesignTokens.Opacity.chipFill)
                             : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    // MARK: - Mode

    private var hasModeControl: Bool {
        guard let f = context.fanModeFeature, let v = f.values else { return false }
        return !v.isEmpty
    }

    private var hasSpeedControl: Bool { context.speedFeature?.range != nil }

    /// Segmented for up to four modes, a menu picker beyond that.
    @ViewBuilder
    private var modeControl: some View {
        if mode == .interactive, let f = context.fanModeFeature, f.isWritable, let modes = f.values {
            let selection = Binding<String>(
                get: { context.fanMode ?? "" },
                set: { m in if let p = context.fanModePayload(m) { onSend(p) } }
            )
            if modes.count <= DesignTokens.Count.segmentedMaxOptions {
                Picker("Mode", selection: selection) {
                    ForEach(modes, id: \.self) { Text(prettify($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            } else {
                HStack {
                    Text("Mode")
                    Spacer()
                    Picker("Mode", selection: selection) {
                        ForEach(modes, id: \.self) { Text(prettify($0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.secondary)
                }
            }
        } else {
            HStack {
                Text("Mode")
                Spacer()
                Text(prettify(context.fanMode ?? "—")).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Speed

    @ViewBuilder
    private var speedControl: some View {
        let f = context.speedFeature
        let range = f?.range ?? 0...100
        let current = context.speedPercent ?? range.lowerBound

        SwiftUI.Group {
            if mode == .interactive, let f, f.isWritable {
                Slider(value: $speedDraft, in: range, step: f.step ?? 1) { editing in
                    guard !editing else { return }
                    if let p = context.speedPayload(speedDraft) { onSend(p) }
                }
                .tint(.teal)
                .accessibilityLabel("Speed")
            }
        }
        .onAppear { speedDraft = current }
        .onChange(of: current) { _, v in speedDraft = v }
    }

    // MARK: - Helpers

    private func prettify(_ s: String) -> String { FanAirReadings.prettify(s) }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = FanControlContext(device: .preview, state: [
                "state": .string("ON"),
                "fan_mode": .string("auto"),
                "fan_speed_percent": .int(60),
                "led_enable": .bool(true),
                "child_lock": .string("UNLOCK"),
                "pm25": .int(9),
                "air_quality": .string("excellent"),
                "replace_filter": .bool(false),
                "filter_age": .int(171315),
                "device_age": .int(164780)
            ]) {
                FanControlCard(context: ctx, mode: .interactive, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
