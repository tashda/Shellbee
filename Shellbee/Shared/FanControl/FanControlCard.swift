import SwiftUI

struct FanControlCard: View {
    let context: FanControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var speedDraft: Double = 0
    @State private var presentedGroup: IndexedGroup?

    private let rowHorizontalPadding: CGFloat = DesignTokens.Spacing.lg
    private let rowVerticalPadding: CGFloat = 12
    private let iconTileSize: CGFloat = 30

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            heroCard
            if hasFilterSection { filterCard }
            ForEach(sections) { section in
                sectionView(section)
            }
        }
        .sheet(item: $presentedGroup) { group in
            FeatureDetailSheet(title: group.label) {
                ForEach(Array(group.members.enumerated()), id: \.element.property) { idx, e in
                    if idx > 0 { rowDivider }
                    FanExtraRow(expose: e, state: context.state, mode: mode,
                                iconTileSize: iconTileSize,
                                horizontalPadding: rowHorizontalPadding,
                                verticalPadding: rowVerticalPadding,
                                onSend: onSend)
                }
            }
        }
    }

    // MARK: - Sectioning

    /// Extras eligible for sectioned display: everything that isn't already
    /// represented in the hero or the dedicated Filter card.
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

    // MARK: - Hero

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

    @ViewBuilder
    private var heroCard: some View {
        let tint = hasAirSensors ? airQualityTint : (context.isOn ? Color.teal : Color(.tertiaryLabel))
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            heroHeadline(tint: tint)
            if hasModeControl || hasSpeedControl {
                heroDivider(tint: tint)
                if hasModeControl { heroModeRow }
                if hasModeControl && hasSpeedControl { heroDivider(tint: tint) }
                if hasSpeedControl { heroSpeedRow }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [tint.opacity(hasAirSensors ? 0.22 : (context.isOn ? 0.18 : 0.05)),
                         tint.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    @ViewBuilder
    private func heroHeadline(tint: Color) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(hasAirSensors ? "Air Quality" : "Fan")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                    .tracking(0.6)

                if hasAirSensors {
                    if let pm = pm25Value {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Int(pm.rounded()).formatted())
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text(pm25Unit)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let aq = airQualityText {
                        Text(prettify(aq))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                } else {
                    Text(context.isOn ? "On" : "Off")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                }
            }
            Spacer()
            powerControl
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
                .tint(.teal)
            } else {
                Text(context.isOn ? "ON" : "OFF")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.isOn ? Color.teal : Color(.secondaryLabel))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        context.isOn ? Color.teal.opacity(DesignTokens.Opacity.chipFill)
                                     : Color(.tertiarySystemFill),
                        in: Capsule()
                    )
        }
    }

    private func heroDivider(tint: Color) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private var hasModeControl: Bool {
        guard let f = context.fanModeFeature, let v = f.values else { return false }
        return !v.isEmpty
    }

    private var hasSpeedControl: Bool { context.speedFeature?.range != nil }

    private var heroModeRow: some View {
        HStack {
            Text("Mode").font(.body)
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
                    HStack(spacing: 4) {
                        Text(prettify(context.fanMode ?? "—"))
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

    @ViewBuilder
    private var heroSpeedRow: some View {
        let f = context.speedFeature
        let range = f?.range ?? 0...100
        let unit = f?.unit ?? "%"
        let current = context.speedPercent ?? range.lowerBound

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Speed").font(.body)
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
                .tint(.teal)
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

    private var filterAgeMinutes: Double? {
        context.state["filter_age"]?.numberValue
    }
    private var deviceAgeMinutes: Double? {
        context.state["device_age"]?.numberValue
    }

    private var filterCard: some View {
        let needsReplace = replaceFilterValue ?? false
        let healthTint: Color = needsReplace ? .orange : .green
        let symbol = needsReplace ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
        let title = needsReplace ? "Replace Filter" : "Filter Healthy"

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white, healthTint)
                    .symbolRenderingMode(.palette)
                    .frame(width: 30, height: 30)
                    .background(healthTint.gradient,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("FILTER")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Text(title).font(.headline)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                if let v = filterAgeMinutes {
                    statColumn(label: "Filter age", value: formatDuration(v))
                }
                if let v = deviceAgeMinutes {
                    statColumn(label: "Device age", value: formatDuration(v))
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section rendering

    @ViewBuilder
    private func sectionView(_ section: LayoutSection) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(section.title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.leading, DesignTokens.Spacing.md)

            groupedCard {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { rowDivider }
                    itemView(item)
                }
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: LayoutItem) -> some View {
        switch item {
        case .row(let expose):
            FanExtraRow(expose: expose, state: context.state, mode: mode,
                        iconTileSize: iconTileSize,
                        horizontalPadding: rowHorizontalPadding,
                        verticalPadding: rowVerticalPadding,
                        onSend: onSend)
        case .indexedGroup(let group):
            DisclosureFeatureRow(
                symbol: group.symbol,
                tint: group.tint,
                label: group.label,
                trailingSummary: "\(group.members.count)",
                iconTileSize: iconTileSize,
                horizontalPadding: rowHorizontalPadding,
                verticalPadding: rowVerticalPadding
            ) {
                presentedGroup = group
            }
        }
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Divider().padding(.leading, rowHorizontalPadding + iconTileSize + DesignTokens.Spacing.md)
    }

    @ViewBuilder
    private func groupedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatDuration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        if hours < 48 { return "\(hours) h" }
        let days = hours / 24
        if days < 60 { return "\(days) d" }
        let months = days / 30
        return "\(months) mo"
    }
}

// MARK: - Extra row

private struct FanExtraRow: View {
    let expose: Expose
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let iconTileSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let onSend: (JSONValue) -> Void

    @State private var numericDraft: Double = 0

    private var property: String { expose.property ?? expose.name ?? "" }
    private var meta: FeatureMeta { FeatureCatalog.meta(for: property, exposeType: expose.type) }
    private var label: String { meta.label }
    private var stateValue: JSONValue? { state[property] }

    var body: some View {
        rowContent
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }

    @ViewBuilder
    private var rowContent: some View {
        switch expose.type {
        case "binary": binaryRow
        case "enum": enumRow
        case "numeric": numericRow
        default: textRow
        }
    }

    @ViewBuilder
    private var binaryRow: some View {
        let isOn = stateValue == expose.valueOn || stateValue?.boolValue == true
        HStack(spacing: DesignTokens.Spacing.md) {
            FeatureIconTile(symbol: meta.symbol, tint: meta.tint, size: iconTileSize)
            labelStack
            Spacer()
            if mode == .interactive, expose.isWritable,
               let on = expose.valueOn, let off = expose.valueOff {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { v in onSend(.object([property: v ? on : off])) }
                ))
                .labelsHidden()
                .tint(.teal)
            } else {
                Text(isOn ? "On" : "Off")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var enumRow: some View {
        let values = expose.values ?? []
        let current = stateValue?.stringValue ?? "—"
        HStack(spacing: DesignTokens.Spacing.md) {
            FeatureIconTile(symbol: meta.symbol, tint: meta.tint, size: iconTileSize)
            labelStack
            Spacer()
            if mode == .interactive, expose.isWritable, !values.isEmpty {
                Menu {
                    ForEach(values, id: \.self) { v in
                        Button {
                            onSend(.object([property: .string(v)]))
                        } label: {
                            if current == v {
                                Label(prettify(v), systemImage: "checkmark")
                            } else {
                                Text(prettify(v))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(prettify(current))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            } else {
                Text(prettify(current)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var numericRow: some View {
        let current = stateValue?.numberValue ?? 0
        let unit = expose.unit ?? ""
        let writable = mode == .interactive && expose.isWritable
            && expose.valueMin != nil && expose.valueMax != nil

        if writable, let min = expose.valueMin, let max = expose.valueMax {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    FeatureIconTile(symbol: meta.symbol, tint: meta.tint, size: iconTileSize)
                    labelStack
                    Spacer()
                    Text(formatNumeric(numericDraft, unit: unit))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $numericDraft, in: min...max, step: expose.valueStep ?? 1) { editing in
                    guard !editing else { return }
                    onSend(.object([property: numericPayload(numericDraft, step: expose.valueStep)]))
                }
                .tint(.teal)
                .padding(.leading, iconTileSize + DesignTokens.Spacing.md)
            }
            .onAppear { numericDraft = current }
            .onChange(of: current) { _, v in numericDraft = v }
        } else {
            HStack(spacing: DesignTokens.Spacing.md) {
                FeatureIconTile(symbol: meta.symbol, tint: meta.tint, size: iconTileSize)
                labelStack
                Spacer()
                Text(formatNumeric(current, unit: unit))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func numericPayload(_ v: Double, step: Double?) -> JSONValue {
        if let step, step.truncatingRemainder(dividingBy: 1) == 0 {
            return .int(Int(v.rounded()))
        }
        return .double(v)
    }

    @ViewBuilder
    private var textRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            FeatureIconTile(symbol: meta.symbol, tint: meta.tint, size: iconTileSize)
            labelStack
            Spacer()
            Text(stateValue?.stringified ?? "—").foregroundStyle(.secondary)
        }
    }

    /// Two-line label: primary title with an optional small secondary
    /// description from `expose.description`. Description is suppressed when
    /// it just restates the label, to avoid noise on rows that explain themselves.
    @ViewBuilder
    private var labelStack: some View {
        if let desc = meaningfulDescription {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(label).font(.body)
        }
    }

    /// Show `expose.description` only when it adds real information the label
    /// can't carry on its own. The cost of a wrong "show" is real (clutter),
    /// so the bar is high — most rows will not pass.
    ///
    /// Show if EITHER:
    ///   • the description contains digits — almost always means a range,
    ///     unit, or specific value that's load-bearing ("0-255 (hue)",
    ///     "in 25ms increments", "0=disabled")
    ///   • the description contributes ≥4 substantive words not already
    ///     implied by the label or common stopwords. "Smart Bulb Mode"
    ///     paired with "Whether device is connected to dumb load or smart
    ///     load" passes; "LED Enable" / "Whether the LED is enabled" doesn't.
    private var meaningfulDescription: String? {
        guard let desc = expose.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              desc.count >= 12 else { return nil }

        // Suppress exact restatements (case- and punctuation-insensitive).
        let normalizedLabel = label.lowercased().filter { $0.isLetter || $0.isNumber }
        let normalizedDesc = desc.lowercased().filter { $0.isLetter || $0.isNumber }
        if normalizedDesc == normalizedLabel { return nil }

        // Numeric content almost always means a range/unit worth showing.
        if desc.contains(where: { $0.isNumber }) { return desc }

        // Word-novelty test: how many substantive words does the description
        // add over the label? Strip stopwords and tokens that are stems of
        // label words ("enabled" vs "Enable", "locks" vs "Lock").
        let labelTokens = tokenize(label).map { $0.lowercased() }
        let descTokens = tokenize(desc).map { $0.lowercased() }
        let novel = descTokens.filter { token in
            if Self.stopwords.contains(token) { return false }
            return !labelTokens.contains { stem in
                token.hasPrefix(stem) || stem.hasPrefix(token)
            }
        }
        return novel.count >= 4 ? desc : nil
    }

    private func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static let stopwords: Set<String> = [
        "a", "an", "the", "this", "that", "these", "those",
        "is", "are", "was", "were", "be", "been", "being",
        "of", "to", "in", "on", "at", "for", "with", "by", "as", "from",
        "and", "or", "but", "if", "when", "while", "whether",
        "it", "its", "this", "you", "your",
        "controls", "control", "sets", "set", "set:", "value", "current",
        "device", "switch"
    ]

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatNumeric(_ v: Double, unit: String) -> String {
        let formatted = v.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
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
