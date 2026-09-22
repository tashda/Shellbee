import SwiftUI

struct FanControlCard: View {
    let context: FanControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void
    /// When `false`, the feature sections (Behaviour / Indicators / etc.) are
    /// suppressed so the caller can render them as native `List` sections.
    /// Defaults to `true` to preserve inline rendering for snapshot contexts
    /// (e.g. LogDetailView) that aren't backed by a List.
    var rendersSectionsInline: Bool = true

    @State private var speedDraft: Double = 0

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(spacing: DesignTokens.Spacing.lg) {
                heroCard
                if FanFilterCard.isRelevant(for: context) { FanFilterCard(context: context) }
                if rendersSectionsInline {
                    FanInlineSections(context: context, extras: eligibleExtras, mode: mode, onSend: onSend)
                }
            }
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
            if let pm = pm25Value { parts.append("\(Int(pm.rounded())) \(pm25Unit)") }
            if let aq = airQualityText { parts.append(prettify(aq)) }
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

    private var eligibleExtras: [Expose] {
        let claimed: Set<String> = Set(["pm25", "air_quality"]).union(FanFilterCard.filterProps)
        return context.extras.filter { e in
            guard let prop = e.property else { return false }
            return !claimed.contains(prop)
        }
    }

    // MARK: - Hero data

    private var pm25Expose: Expose? { context.extras.first { $0.property == "pm25" } }
    private var airQualityExpose: Expose? { context.extras.first { $0.property == "air_quality" } }
    private var hasAirSensors: Bool { airQualityExpose != nil || pm25Expose != nil }

    private var pm25Value: Double? {
        guard let p = pm25Expose?.property else { return nil }
        return context.state[p]?.numberValue
    }
    private var pm25Unit: String { pm25Expose?.unit ?? "µg/m³" }
    private var airQualityText: String? {
        guard let p = airQualityExpose?.property else { return nil }
        return context.state[p]?.stringValue
    }

    /// The single state-derived color that drives the hero gradient, eyebrow,
    /// and any state-text inside the hero. Air-quality devices use an AQI
    /// scale; plain fans use teal when on, neutral when off.
    private var heroTint: Color {
        if hasAirSensors { return airQualityTint }
        return context.isOn ? .teal : Color(.tertiaryLabel)
    }

    private var airQualityTint: Color {
        if let aq = airQualityText {
            switch aq.lowercased() {
            case "excellent": return .green
            case "good": return .mint
            case "moderate", "fair": return .yellow
            case "poor": return .orange
            case "unhealthy", "very_poor", "very poor", "hazardous", "bad": return .red
            default: break
            }
        }
        if let pm = pm25Value {
            switch pm {
            case ..<12: return .green
            case ..<35: return .mint
            case ..<55: return .yellow
            case ..<150: return .orange
            default: return .red
            }
        }
        return .teal
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(
                systemImage: hasAirSensors ? "aqi.medium" : (context.isOn ? "fan.fill" : "fan"),
                title: hasAirSensors ? "Air Quality" : "Fan",
                value: headerValue,
                tint: heroTint
            ) {
                powerControl
            }
            if hasAirSensors, !airItems.isEmpty { StatStrip(items: airItems) }
            if hasModeControl { modeControl }
            if hasSpeedControl { speedControl }
        }
        .cardSurface()
    }

    /// "On · Speed 3", "Off", or for purifiers without a power state the
    /// air quality in words.
    private var headerValue: String {
        guard context.stateFeature != nil else { return airQualityText.map(prettify) ?? "" }
        guard context.isOn else { return "Off" }
        if hasSpeedControl, !hasAirSensors { return "On · Speed \(Int(speedDraft.rounded()))" }
        return "On"
    }

    private var airItems: [StatStripItem] {
        var items: [StatStripItem] = []
        if let pm = pm25Value {
            items.append(StatStripItem(value: "\(Int(pm.rounded())) \(pm25Unit)", caption: "PM2.5"))
        }
        if let aq = airQualityText {
            items.append(StatStripItem(value: prettify(aq), caption: "Air Quality",
                                       valueColor: airQualityNeedsAttention ? airQualityTint : nil))
        }
        return items
    }

    /// Only moderate or worse air earns a colour; good air stays neutral.
    private var airQualityNeedsAttention: Bool {
        [Color.yellow, .orange, .red].contains(airQualityTint)
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

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }
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
