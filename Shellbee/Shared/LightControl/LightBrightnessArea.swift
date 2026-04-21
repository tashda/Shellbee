import SwiftUI

struct LightBrightnessArea: View {
    let isOn: Bool
    let isInteractive: Bool
    let value: Double
    let range: ClosedRange<Double>
    let displayColor: Color
    let onChange: (Double) -> Void
    let onTogglePower: () -> Void

    @State private var draftValue: Double
    @State private var isDragging = false

    private static let height: CGFloat = 56

    init(
        isOn: Bool, isInteractive: Bool,
        value: Double, range: ClosedRange<Double>,
        displayColor: Color,
        onChange: @escaping (Double) -> Void,
        onTogglePower: @escaping () -> Void
    ) {
        self.isOn = isOn
        self.isInteractive = isInteractive
        self.value = value
        self.range = range
        self.displayColor = displayColor
        self.onChange = onChange
        self.onTogglePower = onTogglePower
        _draftValue = State(initialValue: value)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                fillBar(width: proxy.size.width)
                labelRow
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .disabled(!isInteractive)
            .gesture(interactionGesture(totalWidth: proxy.size.width))
        }
        .frame(height: Self.height)
        .onChange(of: value) { _, v in
            guard !isDragging else { return }
            draftValue = v
        }
    }

    private func fillBar(width: CGFloat) -> some View {
        Rectangle()
            .fill(displayColor.opacity(isOn ? 0.75 : 0.18))
            .frame(width: max(0, width * clampedFraction))
            .animation(isDragging ? .none : .spring(response: 0.35, dampingFraction: 1), value: clampedFraction)
    }

    private var labelRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: isOn ? "lightbulb.max.fill" : "lightbulb.slash.fill")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Text(isOn ? "\(brightnessPercent)%" : "Off")
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    private var clampedFraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return max(0, min(1, (draftValue - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    private var brightnessPercent: Int {
        Int((clampedFraction * 100).rounded())
    }

    private func interactionGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let moved = hypot(g.translation.width, g.translation.height)
                guard moved > 8 else { return }
                isDragging = true
                draftValue = valueAt(x: g.location.x, totalWidth: totalWidth)
            }
            .onEnded { g in
                let moved = hypot(g.translation.width, g.translation.height)
                defer { isDragging = false }
                if moved < 8 {
                    onTogglePower()
                } else {
                    let final = valueAt(x: g.location.x, totalWidth: totalWidth)
                    draftValue = final
                    onChange(final)
                }
            }
    }

    private func valueAt(x: CGFloat, totalWidth: CGFloat) -> Double {
        let f = max(0, min(1, x / totalWidth))
        return range.lowerBound + f * (range.upperBound - range.lowerBound)
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
