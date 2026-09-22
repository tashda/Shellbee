import SwiftUI

/// The colour temperature a light uses when it powers on: z2m's presets
/// (Previous, Coolest … Warmest) as a checkmark list, and a Custom slider for
/// an exact value.
struct LightStartupTemperaturePage: View {
    private enum Selection: Equatable {
        case preset(String)
        case custom
    }

    let feature: LightAdvancedFeature
    let range: ClosedRange<Double>?
    let onChange: (Double) -> Void

    @State private var draft: Double
    @State private var selection: Selection

    init(feature: LightAdvancedFeature, range: ClosedRange<Double>?, value: Double,
         onChange: @escaping (Double) -> Void) {
        self.feature = feature
        self.range = range
        self.onChange = onChange
        _draft = State(initialValue: value)
        if let preset = feature.presets.first(where: {
            Int($0.value.numberValue ?? -1) == Int(value.rounded())
        }) {
            _selection = State(initialValue: .preset(preset.name))
        } else {
            _selection = State(initialValue: .custom)
        }
    }

    var body: some View {
        List {
            if !feature.presets.isEmpty {
                Section {
                    ForEach(feature.presets, id: \.name) { preset in
                        presetRow(preset)
                    }
                } footer: {
                    Text("Previous keeps the colour temperature the light had before it lost power.")
                }
            }
            if let range {
                Section {
                    Button {
                        selectCustom(in: range)
                    } label: {
                        HStack {
                            Text("Custom")
                                .foregroundStyle(.primary)
                            Spacer()
                            SelectionIndicator(isSelected: selection == .custom)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == .custom ? .isSelected : [])

                    if selection == .custom {
                        LabeledContent("Temperature") {
                            Text(Self.kelvinText(draft))
                                .monospacedDigit()
                        }
                        // Kelvin runs opposite to mireds, so the slider is
                        // flipped to read warm on the left, cool on the right.
                        Slider(
                            value: Binding(get: { range.upperBound + range.lowerBound - draft },
                                           set: { draft = range.upperBound + range.lowerBound - $0 }),
                            in: range
                        ) { editing in
                            guard !editing else { return }
                            onChange(draft)
                        }
                        .tint(Self.swatch(for: draft))
                        .accessibilityHint("Adjusts the Custom color temperature")
                    }
                }
            }
        }
        .navigationTitle(feature.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetRow(_ preset: ExposePreset) -> some View {
        let mireds = preset.value.numberValue ?? 0
        let isSelected = selection == .preset(preset.name)
        return Button {
            draft = mireds
            selection = .preset(preset.name)
            onChange(mireds)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Circle()
                    .fill(Self.isPrevious(mireds) ? Color(.tertiarySystemFill) : Self.swatch(for: mireds))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(DesignTokens.Opacity.hairline)))
                    .frame(width: DesignTokens.Size.changeSwatch, height: DesignTokens.Size.changeSwatch)
                Text(Self.presetName(preset.name))
                    .foregroundStyle(.primary)
                Spacer()
                if !Self.isPrevious(mireds) {
                    Text(Self.kelvinText(mireds))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: DesignTokens.Size.temperatureKelvinColumn, alignment: .trailing)
                }
                SelectionIndicator(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectCustom(in range: ClosedRange<Double>) {
        selection = .custom
        if !range.contains(draft) {
            draft = (range.lowerBound + range.upperBound) / 2
        }
    }

    // MARK: - Formatting

    /// The row summary: the preset's name when the value matches one,
    /// otherwise the kelvin value.
    static func summary(for mireds: Double, presets: [ExposePreset]) -> String {
        if let match = presets.first(where: { Int($0.value.numberValue ?? -1) == Int(mireds.rounded()) }) {
            return presetName(match.name)
        }
        return mireds > 0 ? kelvinText(mireds) : "—"
    }

    private static func presetName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// z2m uses 65535 for "previous".
    private static func isPrevious(_ mireds: Double) -> Bool { mireds >= 65_535 }

    private static func kelvinText(_ mireds: Double) -> String {
        "\(Int((1_000_000 / max(mireds, 1)).rounded())) K"
    }

    private static func swatch(for mireds: Double) -> Color {
        LightDisplayColor.temperatureColor(mireds: mireds)
    }
}
