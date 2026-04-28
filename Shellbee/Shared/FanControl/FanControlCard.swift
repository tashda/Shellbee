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
    @State private var presentedGroup: IndexedGroup?

    private let rowHorizontalPadding: CGFloat = DesignTokens.Spacing.lg
    private let rowVerticalPadding: CGFloat = DesignTokens.Spacing.md
    private let rowIconWidth: CGFloat = DesignTokens.Size.cardSymbol

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            heroCard
            if hasFilterSection { filterCard }
            if rendersSectionsInline {
                ForEach(sections) { section in
                    sectionView(section)
                }
            }
        }
        .sheet(item: $presentedGroup) { group in
            FeatureDetailSheet(title: group.label) {
                ForEach(Array(group.members.enumerated()), id: \.element.property) { idx, e in
                    if idx > 0 { rowDivider }
                    FanExtraRow(expose: e, state: context.state, mode: mode,
                                horizontalPadding: rowHorizontalPadding,
                                verticalPadding: rowVerticalPadding,
                                iconWidth: rowIconWidth,
                                onSend: onSend)
                }
            }
        }
    }

    // MARK: - Sectioning

    private var eligibleExtras: [Expose] {
        let claimed: Set<String> = Set(["pm25", "air_quality"]).union(filterProps)
        return context.extras.filter { e in
            guard let prop = e.property else { return false }
            return !claimed.contains(prop)
        }
    }

    private var sections: [LayoutSection] {
        FeatureLayout.sections(from: eligibleExtras)
    }

    private let filterProps: Set<String> = ["replace_filter", "filter_age", "device_age"]
    private var hasFilterSection: Bool {
        context.extras.contains { filterProps.contains($0.property ?? "") }
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

    @ViewBuilder
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            heroHeadline
            if hasModeControl || hasSpeedControl {
                hairline
                if hasModeControl { heroModeRow }
                if hasModeControl && hasSpeedControl { hairline }
                if hasSpeedControl { heroSpeedRow }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var heroBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [
                    heroTint.opacity(hasAirSensors ? 0.20 : (context.isOn ? 0.18 : 0.06)),
                    heroTint.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

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
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: hasAirSensors ? "aqi.medium" : (context.isOn ? "fan.fill" : "fan"))
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text(hasAirSensors ? "Air Quality" : "Fan")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(heroTint)
    }

    @ViewBuilder
    private var heroValue: some View {
        if hasAirSensors {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                if let pm = pm25Value {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                        Text(Int(pm.rounded()).formatted())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(pm25Unit)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                if let aq = airQualityText {
                    Text(prettify(aq))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(heroTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        } else {
            Text(context.isOn ? "On" : "Off")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(heroTint)
        }
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

    /// Toggles get the live state tint while the fan is on, and a sane teal
    /// while off (so they read as "tappable to turn on" rather than disabled).
    private var toggleTint: Color {
        context.isOn ? heroTint : .teal
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

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: DesignTokens.Size.hairline)
    }

    // MARK: - Hero mode row

    private var hasModeControl: Bool {
        guard let f = context.fanModeFeature, let v = f.values else { return false }
        return !v.isEmpty
    }

    private var hasSpeedControl: Bool { context.speedFeature?.range != nil }

    private var heroModeRow: some View {
        HStack {
            Text("Mode").font(.body).foregroundStyle(.primary)
            Spacer()
            if mode == .interactive, let f = context.fanModeFeature, f.isWritable, let modes = f.values {
                Menu {
                    ForEach(modes, id: \.self) { m in
                        Button {
                            if let p = context.fanModePayload(m) { onSend(p) }
                        } label: {
                            if context.fanMode == m {
                                Label(prettify(m), systemImage: "checkmark")
                            } else {
                                Text(prettify(m))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(prettify(context.fanMode ?? "—"))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            } else {
                Text(prettify(context.fanMode ?? "—")).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hero speed row

    @ViewBuilder
    private var heroSpeedRow: some View {
        let f = context.speedFeature
        let range = f?.range ?? 0...100
        let unit = f?.unit ?? "%"
        let current = context.speedPercent ?? range.lowerBound

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Speed").font(.body).foregroundStyle(.primary)
                Spacer()
                Text("\(Int(speedDraft.rounded()))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if mode == .interactive, let f, f.isWritable {
                Slider(value: $speedDraft, in: range, step: f.step ?? 1) { editing in
                    guard !editing else { return }
                    if let p = context.speedPayload(speedDraft) { onSend(p) }
                }
                .tint(toggleTint)
            }
        }
        .onAppear { speedDraft = current }
        .onChange(of: current) { _, v in speedDraft = v }
    }

    // MARK: - Filter card

    private var replaceFilterValue: Bool? {
        guard let e = context.extras.first(where: { $0.property == "replace_filter" }),
              let p = e.property else { return nil }
        let v = context.state[p]
        if v == e.valueOn { return true }
        if v == e.valueOff { return false }
        return v?.boolValue
    }

    private var filterAgeMinutes: Double? { context.state["filter_age"]?.numberValue }
    private var deviceAgeMinutes: Double? { context.state["device_age"]?.numberValue }

    private var filterCard: some View {
        let needsReplace = replaceFilterValue ?? false
        let tint: Color = needsReplace ? .orange : .green
        let title = needsReplace ? "Replace" : "Healthy"
        let icon = needsReplace ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                    Text("Filter")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }
                .foregroundStyle(tint)

                Text(title)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            if filterAgeMinutes != nil || deviceAgeMinutes != nil {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading),
                    GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading)
                ], alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    if let v = filterAgeMinutes {
                        ageTile(label: "Filter Age", minutes: v, icon: "calendar")
                    }
                    if let v = deviceAgeMinutes {
                        ageTile(label: "Device Age", minutes: v, icon: "clock")
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [tint.opacity(0.10), tint.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private func ageTile(label: String, minutes: Double, icon: String) -> some View {
        let parts = formatDurationParts(minutes)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
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

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(parts.value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(parts.unit)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section rendering

    @ViewBuilder
    private func sectionView(_ section: LayoutSection) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.leading, DesignTokens.Spacing.md)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { rowDivider }
                    itemView(item)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                    radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        }
    }

    @ViewBuilder
    private func itemView(_ item: LayoutItem) -> some View {
        switch item {
        case .row(let expose):
            FanExtraRow(expose: expose, state: context.state, mode: mode,
                        horizontalPadding: rowHorizontalPadding,
                        verticalPadding: rowVerticalPadding,
                        iconWidth: rowIconWidth,
                        onSend: onSend)
        case .indexedGroup(let group):
            DisclosureRow(
                symbol: group.symbol,
                label: group.label,
                trailingSummary: "\(group.members.count)",
                horizontalPadding: rowHorizontalPadding,
                verticalPadding: rowVerticalPadding,
                iconWidth: rowIconWidth
            ) { presentedGroup = group }
        }
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Divider().padding(.leading, rowHorizontalPadding + rowIconWidth + DesignTokens.Spacing.md)
    }

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatDurationParts(_ minutes: Double) -> (value: String, unit: String) {
        let total = Int(minutes.rounded())
        if total < 60 { return ("\(total)", "min") }
        let hours = total / 60
        if hours < 48 { return ("\(hours)", "h") }
        let days = hours / 24
        if days < 60 { return ("\(days)", "d") }
        let months = days / 30
        return ("\(months)", "mo")
    }
}

// MARK: - Disclosure row (monochrome, local to fan card)

private struct DisclosureRow: View {
    let symbol: String
    let label: String
    let trailingSummary: String?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: iconWidth)
                Text(label).font(.body).foregroundStyle(.primary)
                Spacer()
                if let trailingSummary {
                    Text(trailingSummary).font(.body).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
