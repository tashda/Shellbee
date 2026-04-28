import SwiftUI

/// Renders a single `Expose` as a native iOS Settings-style row inside a
/// grouped `Form` / inset-grouped `List` section. Plain label on the left,
/// value or control on the right. Writable numerics show their slider
/// **inline** (label + value on top, slider beneath) — never push to a
/// separate detail screen.
///
/// Used by `FanFeatureSections`, `SwitchFeatureSections`,
/// `ClimateFeatureSections`, `CoverFeatureSections` to surface "leftover"
/// exposes that the category card itself does not bind to a primary control.
struct SettingsFormRow: View {
    let expose: Expose
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var numericDraft: Double = 0

    private var property: String { expose.property ?? expose.name ?? "" }
    private var meta: FeatureMeta { FeatureCatalog.meta(for: property, exposeType: expose.type) }
    private var label: String { meta.label }
    private var stateValue: JSONValue? { state[property] }

    var body: some View {
        switch expose.type {
        case "binary":  binaryRow
        case "enum":    enumRow
        case "numeric": numericRow
        default:        textRow
        }
    }

    @ViewBuilder
    private var binaryRow: some View {
        let isOn = stateValue == expose.valueOn || stateValue?.boolValue == true
        if mode == .interactive, expose.isWritable,
           let on = expose.valueOn, let off = expose.valueOff {
            Toggle(label, isOn: Binding(
                get: { isOn },
                set: { v in onSend(.object([property: v ? on : off])) }
            ))
        } else {
            LabeledContent(label) { Text(isOn ? "On" : "Off") }
        }
    }

    @ViewBuilder
    private var enumRow: some View {
        let values = expose.values ?? []
        let current = stateValue?.stringValue ?? ""
        if mode == .interactive, expose.isWritable, !values.isEmpty {
            Picker(label, selection: Binding(
                get: { current },
                set: { onSend(.object([property: .string($0)])) }
            )) {
                ForEach(values, id: \.self) { v in
                    Text(prettify(v)).tag(v)
                }
            }
        } else {
            LabeledContent(label) { Text(prettify(current.isEmpty ? "—" : current)) }
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
                LabeledContent(label) {
                    Text(format(numericDraft, unit: unit))
                        .monospacedDigit()
                }
                Slider(value: $numericDraft, in: min...max, step: expose.valueStep ?? 1) { editing in
                    guard !editing else { return }
                    onSend(.object([property: numericPayload(numericDraft, step: expose.valueStep)]))
                }
            }
            .accessibilityElement(children: .contain)
            .onAppear { numericDraft = current }
            .onChange(of: current) { _, v in numericDraft = v }
        } else {
            LabeledContent(label) { Text(format(current, unit: unit)) }
        }
    }

    @ViewBuilder
    private var textRow: some View {
        LabeledContent(label) { Text(stateValue?.stringified ?? "—") }
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

    private func format(_ v: Double, unit: String) -> String {
        let s = v.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? s : "\(s) \(unit)"
    }
}
