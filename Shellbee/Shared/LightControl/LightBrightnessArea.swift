import SwiftUI

/// Brightness capsule for the Light card: fill in the bulb's colour, tap
/// to toggle power, drag to set brightness.
struct LightBrightnessArea: View {
    let isOn: Bool
    let isInteractive: Bool
    let value: Double
    let range: ClosedRange<Double>
    let displayColor: Color
    let onChange: (Double) -> Void
    let onTogglePower: () -> Void

    var body: some View {
        ValueCapsule(
            value: value,
            range: range,
            fillColor: displayColor.opacity(isOn ? 0.75 : 0.18),
            systemImage: isOn ? "lightbulb.max.fill" : "lightbulb.slash.fill",
            isInteractive: isInteractive,
            label: { isOn ? "\(percent(of: $0))%" : "Off" },
            onChange: onChange,
            onTap: onTogglePower
        )
    }

    private func percent(of value: Double) -> Int {
        guard range.upperBound > range.lowerBound else { return 0 }
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return Int((max(0, min(1, fraction)) * 100).rounded())
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        LightBrightnessArea(isOn: true, isInteractive: true, value: 160, range: 0...254,
            displayColor: .yellow, onChange: { _ in }, onTogglePower: {})
        LightBrightnessArea(isOn: false, isInteractive: true, value: 120, range: 0...254,
            displayColor: .cyan, onChange: { _ in }, onTogglePower: {})
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
