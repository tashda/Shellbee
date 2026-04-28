import SwiftUI

struct GenericExposeCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    private static let skipTypes: Set<String> = ["light", "switch", "cover", "lock", "fan", "climate"]

    /// Properties already covered by the device header card (linkquality,
    /// battery, OTA badges, last seen) — surfacing them here would just
    /// duplicate signal a few pixels above. `identify*` is a write-only ping
    /// command with no useful state, so we hide that too.
    private static let skipProperties: Set<String> = [
        "linkquality", "battery", "battery_low",
        "last_seen", "update", "update_available"
    ]

    private let rowHorizontalPadding: CGFloat = DesignTokens.Spacing.lg
    private let rowVerticalPadding: CGFloat = DesignTokens.Spacing.md
    private let rowIconWidth: CGFloat = 22

    var body: some View {
        let rows = Self.rows(for: device, state: state)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if mode == .snapshot { snapshotHeader }
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    if idx > 0 { rowDivider }
                    GenericExposeRow(
                        row: row,
                        mode: mode,
                        horizontalPadding: rowHorizontalPadding,
                        verticalPadding: rowVerticalPadding,
                        iconWidth: rowIconWidth,
                        onSend: onSend
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                    radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
        }
    }

    /// Snapshot-only eyebrow. Interactive mode drops it entirely — the device
    /// name above the card already names what we're looking at, so a redundant
    /// "Controls" / "Device State" headline is just noise.
    private var snapshotHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tint)
            Text("Device State")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.top, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, rowHorizontalPadding + rowIconWidth + DesignTokens.Spacing.md)
    }

    static func rows(for device: Device, state: [String: JSONValue]) -> [ExposeRow] {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattenedLeaves
        return flat.compactMap { expose -> ExposeRow? in
            guard !Self.skipTypes.contains(expose.type) else { return nil }
            guard expose.isReadable || expose.isWritable else { return nil }
            let prop = expose.property ?? expose.name ?? ""
            guard !prop.isEmpty else { return nil }
            guard !Self.skipProperties.contains(prop), !prop.hasPrefix("identify") else { return nil }
            return ExposeRow(expose: expose, property: prop, stateValue: state[prop])
        }
    }
}

struct ExposeRow: Identifiable {
    let expose: Expose
    let property: String
    let stateValue: JSONValue?

    var id: String { property }

    var label: String {
        expose.label ?? property.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct GenericExposeRow: View {
    let row: ExposeRow
    let mode: CardDisplayMode
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconWidth: CGFloat
    let onSend: (JSONValue) -> Void

    @State private var numericDraft: Double = 0

    private var meta: FeatureMeta {
        FeatureCatalog.meta(for: row.property, exposeType: row.expose.type)
    }

    var body: some View {
        rowContent
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }

    @ViewBuilder
    private var rowContent: some View {
        switch row.expose.type {
        case "binary": binaryRow
        case "enum": enumRow
        case "numeric": numericRow
        default: textRow
        }
    }

    private var leadingIcon: some View {
        Image(systemName: meta.symbol)
            .font(.system(size: 16, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: iconWidth)
    }

    private var labelText: some View {
        Text(row.label).font(.body).foregroundStyle(.primary)
    }

    @ViewBuilder
    private var binaryRow: some View {
        let isOn = row.stateValue == row.expose.valueOn || row.stateValue?.boolValue == true
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingIcon
            labelText
            Spacer()
            if mode == .interactive, row.expose.isWritable,
               let on = row.expose.valueOn, let off = row.expose.valueOff {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { v in onSend(.object([row.property: v ? on : off])) }
                ))
                .labelsHidden()
            } else {
                Text(isOn ? "On" : "Off").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var enumRow: some View {
        let values = row.expose.values ?? []
        let current = row.stateValue?.stringValue ?? "—"
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingIcon
            labelText
            Spacer()
            if mode == .interactive, row.expose.isWritable, !values.isEmpty {
                Menu {
                    ForEach(values, id: \.self) { v in
                        Button {
                            onSend(.object([row.property: .string(v)]))
                        } label: {
                            if current == v {
                                Label(prettify(v), systemImage: "checkmark")
                            } else {
                                Text(prettify(v))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
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
        let current = row.stateValue?.numberValue ?? 0
        let unit = row.expose.unit ?? ""
        let writable = mode == .interactive && row.expose.isWritable
            && row.expose.valueMin != nil && row.expose.valueMax != nil

        if writable, let min = row.expose.valueMin, let max = row.expose.valueMax {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    leadingIcon
                    labelText
                    Spacer()
                    Text(formatNumeric(numericDraft, unit: unit))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $numericDraft, in: min...max, step: row.expose.valueStep ?? 1) { editing in
                    guard !editing else { return }
                    onSend(.object([row.property: numericPayload(numericDraft, step: row.expose.valueStep)]))
                }
                .padding(.leading, iconWidth + DesignTokens.Spacing.md)
            }
            .onAppear { numericDraft = current }
            .onChange(of: current) { _, v in numericDraft = v }
        } else {
            HStack(spacing: DesignTokens.Spacing.md) {
                leadingIcon
                labelText
                Spacer()
                Text(formatNumeric(current, unit: unit))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var textRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingIcon
            labelText
            Spacer()
            Text(row.stateValue?.stringified ?? "—").foregroundStyle(.secondary)
        }
    }

    private func numericPayload(_ v: Double, step: Double?) -> JSONValue {
        if let step, step.truncatingRemainder(dividingBy: 1) == 0 {
            return .int(Int(v.rounded()))
        }
        return .double(v)
    }

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
            GenericExposeCard(device: .preview, state: [
                "power_on_behavior": .string("previous"),
                "transition": .double(3)
            ], mode: .interactive, onSend: { _ in })
            GenericExposeCard(device: .preview, state: [
                "power_on_behavior": .string("on"),
                "transition": .double(1)
            ], mode: .snapshot, onSend: { _ in })
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
