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

    private func temperatureRow(range: ClosedRange<Double>?) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(feature.displayLabel)
                Spacer()
                Text("\(Int((1_000_000 / max(numericDraftValue, 1)).rounded()).formatted(.number.grouping(.never)))K")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let range {
                let kelvinRange = (1_000_000 / range.upperBound)...(1_000_000 / max(range.lowerBound, 1))
                Slider(value: kelvinBinding, in: kelvinRange) { editing in
                    guard !editing else { return }
                    onChange(.double(numericDraftValue))
                }
                .tint(LightDisplayColor.temperatureColor(mireds: numericDraftValue))
                .onChange(of: feature.value?.numberValue ?? 0) { _, newValue in
                    numericDraftValue = newValue
                }
            }
        }
    }

    private func numericRow(range: ClosedRange<Double>?, step: Double?) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(feature.displayLabel)
                Spacer()
                Text(numericDraftValue.formatted(.number.precision(.fractionLength(0...1))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let range {
                Slider(value: $numericDraftValue, in: range) { editing in
                    guard !editing else { return }
                    onChange(.double(numericDraftValue))
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
                        if !isFocused { onChange(.double(numericDraftValue)) }
                    }
            }
        }
    }

    private var kelvinBinding: Binding<Double> {
        Binding(
            get: { 1_000_000 / max(numericDraftValue, 1) },
            set: { numericDraftValue = 1_000_000 / max($0, 1) }
        )
    }
}
