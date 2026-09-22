import SwiftUI

struct LightAdvancedFeatureRow: View {
    let feature: LightAdvancedFeature
    let onChange: (JSONValue) -> Void

    @State private var numericDraftValue: Double
    @FocusState private var numericFocused: Bool

    init(feature: LightAdvancedFeature, onChange: @escaping (JSONValue) -> Void) {
        self.feature = feature
        self.onChange = onChange
        var initial = feature.value?.numberValue ?? 0
        if feature.isColorTemperatureMireds, initial <= 0 {
            if case .numeric(let range, _) = feature.kind, let range {
                initial = (range.lowerBound + range.upperBound) / 2
            }
        }
        _numericDraftValue = State(initialValue: initial)
    }

    var body: some View {
        switch feature.kind {
        case .binary(let valueOn, let valueOff):
            Toggle(isOn: Binding(
                get: { feature.value == valueOn },
                set: { onChange($0 ? valueOn : valueOff) }
            )) {
                Text(feature.displayLabel)
            }
        case .enumeration(let values):
            Picker(feature.displayLabel, selection: Binding(
                get: { feature.value?.stringValue ?? values.first ?? "" },
                set: { onChange(.string($0)) }
            )) {
                ForEach(values, id: \.self) { value in
                    Text(value.replacingOccurrences(of: "_", with: " ").capitalized).tag(value)
                }
            }
        case .numeric(let range, let step):
            if feature.isColorTemperatureMireds {
                temperatureRow(range: range)
            } else {
                numericRow(range: range, step: step)
            }
        }
    }

    /// One line showing the current choice; the presets and a custom
    /// slider live on their own page, like Settings › Display › Night Shift.
    private func temperatureRow(range: ClosedRange<Double>?) -> some View {
        NavigationLink {
            LightStartupTemperaturePage(
                feature: feature,
                range: range,
                value: numericDraftValue,
                onChange: { mireds in
                    numericDraftValue = mireds
                    onChange(.int(Int(mireds.rounded())))
                }
            )
        } label: {
            LabeledContent(feature.displayLabel) {
                Text(LightStartupTemperaturePage.summary(for: numericDraftValue, presets: feature.presets))
            }
        }
        .onChange(of: feature.value?.numberValue ?? 0) { _, newValue in
            numericDraftValue = newValue
        }
    }

    /// Same layout as `SettingsFormRow`: label and value on one line, the
    /// slider beneath, committing once when the drag ends.
    private func numericRow(range: ClosedRange<Double>?, step: Double?) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            LabeledContent(feature.displayLabel) {
                Text(numericDraftValue.formatted(.number.precision(.fractionLength(0...1))))
                    .monospacedDigit()
            }

            if let range {
                Slider(value: $numericDraftValue, in: range, step: step ?? 1) { editing in
                    guard !editing else { return }
                    onChange(payloadValue(numericDraftValue, step: step))
                }
                .onChange(of: feature.value?.numberValue ?? 0) { _, newValue in
                    numericDraftValue = newValue
                }
            } else {
                TextField("", value: $numericDraftValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($numericFocused)
                    .onChange(of: numericFocused) { _, isFocused in
                        if !isFocused { onChange(payloadValue(numericDraftValue, step: step)) }
                    }
            }
        }
    }

    /// Whole numbers go out as integers, as z2m expects for stepped values.
    private func payloadValue(_ value: Double, step: Double?) -> JSONValue {
        if (step ?? 1).truncatingRemainder(dividingBy: 1) == 0 { return .int(Int(value.rounded())) }
        return .double(value)
    }
}
