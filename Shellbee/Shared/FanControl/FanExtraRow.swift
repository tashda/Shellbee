import SwiftUI

/// A row that renders an arbitrary fan-related `Expose` (binary / enum /
/// numeric / text) inline inside the `FanControlCard`'s "Extras" section.
/// Mirrors the row chrome of `SettingsFormRow` but is monochrome and
/// fan-specific so it can sit on the card surface rather than in a `List`.
struct FanExtraRow: View {
    let expose: Expose
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconWidth: CGFloat
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

    private var leadingIcon: some View {
        Image(systemName: meta.symbol)
            .font(DesignTokens.Typography.formRowIcon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: iconWidth)
    }

    @ViewBuilder
    private var binaryRow: some View {
        let isOn = stateValue == expose.valueOn || stateValue?.boolValue == true
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingIcon
            labelStack
            Spacer()
            if mode == .interactive, expose.isWritable,
               let on = expose.valueOn, let off = expose.valueOff {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { v in onSend(.object([property: v ? on : off])) }
                ))
                .labelsHidden()
            } else {
                Text(isOn ? "On" : "Off").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var enumRow: some View {
        let values = expose.values ?? []
        let current = stateValue?.stringValue ?? "—"
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingIcon
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
        let current = stateValue?.numberValue ?? 0
        let unit = expose.unit ?? ""
        let writable = mode == .interactive && expose.isWritable
            && expose.valueMin != nil && expose.valueMax != nil

        if writable, let min = expose.valueMin, let max = expose.valueMax {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    leadingIcon
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
                .padding(.leading, iconWidth + DesignTokens.Spacing.md)
            }
            .onAppear { numericDraft = current }
            .onChange(of: current) { _, v in numericDraft = v }
        } else {
            HStack(spacing: DesignTokens.Spacing.md) {
                leadingIcon
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
            leadingIcon
            labelStack
            Spacer()
            Text(stateValue?.stringified ?? "—").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var labelStack: some View {
        Text(label).font(.body)
    }

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatNumeric(_ v: Double, unit: String) -> String {
        let formatted = v.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
    }
}
