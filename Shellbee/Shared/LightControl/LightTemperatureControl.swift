import SwiftUI

struct LightTemperatureControl: View {
    let range: ClosedRange<Double>
    let value: Double
    let isInteractive: Bool
    let onChange: (Double) -> Void

    @State private var draftValue: Double

    /// Five stops across what this light can reach, warmest first, so every
    /// preset is one the bulb can actually show.
    private var presets: [(mireds: Double, label: String)] {
        let warmest = 1_000_000 / range.upperBound
        let coolest = 1_000_000 / range.lowerBound
        return (0..<5).map { step in
            let kelvin = ((warmest + (coolest - warmest) * Double(step) / 4) / 100).rounded() * 100
            let label = kelvin.truncatingRemainder(dividingBy: 1000) == 0
                ? "\(Int(kelvin / 1000))K"
                : String(format: "%.1fK", kelvin / 1000)
            return (min(max(1_000_000 / kelvin, range.lowerBound), range.upperBound), label)
        }
    }

    init(range: ClosedRange<Double>, value: Double, isInteractive: Bool, onChange: @escaping (Double) -> Void) {
        self.range = range
        self.value = value
        self.isInteractive = isInteractive
        self.onChange = onChange
        _draftValue = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(temperatureCategory)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(temperatureLabel)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            // Mireds run opposite to kelvin; flip so warm is on the left,
            // matching the presets beneath.
            Slider(
                value: Binding(get: { range.upperBound + range.lowerBound - draftValue },
                               set: { draftValue = range.upperBound + range.lowerBound - $0 }),
                in: range
            ) { editing in
                guard !editing else { return }
                onChange(draftValue)
            }
            .disabled(!isInteractive)
            .tint(LightDisplayColor.temperatureColor(mireds: draftValue))
            .onChange(of: value) { _, newValue in draftValue = newValue }

            presetsRow
        }
    }

    private var presetsRow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(presets, id: \.label) { preset in
                let mireds = preset.mireds
                let isSelected = abs(draftValue - mireds) < 10

                Button {
                    draftValue = mireds
                    onChange(mireds)
                } label: {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(LightDisplayColor.temperatureColor(mireds: mireds))
                            .frame(width: DesignTokens.Size.lightControlButton, height: DesignTokens.Size.lightControlButton)
                            .overlay(Circle().strokeBorder(
                                isSelected ? Color.primary : Color.clear,
                                lineWidth: DesignTokens.Size.lightSelectionStroke
                            ))
                        Text(preset.label)
                            .font(DesignTokens.Typography.sliderEndLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .disabled(!isInteractive)
            }
        }
    }

    private var temperatureLabel: String {
        let kelvin = Int((1_000_000 / max(draftValue, 1)).rounded())
        return "\(kelvin)K"
    }

    private var temperatureCategory: String {
        let kelvin = 1_000_000 / max(draftValue, 1)
        if kelvin < 3000 { return "Warm" }
        if kelvin < 4500 { return "Neutral" }
        return "Cool"
    }
}

#Preview {
    LightTemperatureControl(range: 153...500, value: 300, isInteractive: true, onChange: { _ in })
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
}
