import SwiftUI

struct LightTemperatureControl: View {
    let range: ClosedRange<Double>
    let value: Double
    let isInteractive: Bool
    let onChange: (Double) -> Void

    @State private var draftValue: Double

    private static let presets: [(kelvin: Double, label: String)] = [
        (2700, "2.7K"), (3000, "3K"), (4000, "4K"), (5000, "5K"), (6500, "6.5K")
    ]

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

            Slider(value: $draftValue, in: range) { editing in
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
            ForEach(Self.presets, id: \.kelvin) { preset in
                let mireds = 1_000_000 / preset.kelvin
                let inRange = range.contains(mireds)
                let isSelected = abs(draftValue - mireds) < 10

                Button {
                    guard inRange else { return }
                    draftValue = mireds
                    onChange(mireds)
                } label: {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(LightDisplayColor.temperatureColor(mireds: mireds))
                            .frame(width: DesignTokens.Size.lightControlButton, height: DesignTokens.Size.lightControlButton)
                            .overlay(Circle().strokeBorder(
                                isSelected ? Color.primary : Color.clear, lineWidth: 2
                            ))
                            .opacity(inRange ? 1 : 0.35)
                        Text(preset.label)
                            .font(DesignTokens.Typography.sliderEndLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .disabled(!isInteractive || !inRange)
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
