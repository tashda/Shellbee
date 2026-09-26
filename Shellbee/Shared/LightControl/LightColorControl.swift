import SwiftUI

struct LightColorControl: View {
    let value: Color
    let isInteractive: Bool
    /// Only mark a swatch when the light is on and showing a colour.
    var showsSelection: Bool = true
    let onChange: (Color) -> Void

    @State private var customColor: Color
    // Suppress the next `customColor` change emitted as a side-effect of
    // syncing from the external `value` (bridge echo). Without this, the
    // ColorPicker re-publishes the echoed color, the bridge echoes again,
    // and any small round-trip rounding (rgb→xy→rgb) drifts the color
    // forever — the "repeating messages" feedback loop.
    @State private var suppressEcho = false
    @State private var publishTask: Task<Void, Never>?

    private static let swatches: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .cyan, .blue, .purple, .pink
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)
    private static let swatchSize: CGFloat = 36

    init(value: Color, isInteractive: Bool, showsSelection: Bool = true, onChange: @escaping (Color) -> Void) {
        self.value = value
        self.isInteractive = isInteractive
        self.showsSelection = showsSelection
        self.onChange = onChange
        _customColor = State(initialValue: value)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(Self.swatches.enumerated()), id: \.offset) { _, swatch in
                swatchButton(swatch)
            }
            customButton
        }
        .onChange(of: value) { _, newValue in
            guard newValue.hexString != customColor.hexString else { return }
            suppressEcho = true
            customColor = newValue
        }
    }

    private func swatchButton(_ color: Color) -> some View {
        Button {
            publishTask?.cancel()
            suppressEcho = true
            customColor = color
            onChange(color)
        } label: {
            Circle()
                .fill(color)
                .padding(isSelected(color) ? DesignTokens.Size.lightSelectionStroke * 2 : 0)
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(Circle().strokeBorder(isSelected(color) ? Color.primary : Color.clear, lineWidth: DesignTokens.Size.lightSelectionStroke))
                .frame(maxWidth: .infinity)
                .contentShape(Circle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
    }

    private var customButton: some View {
        ColorPicker(selection: $customColor, supportsOpacity: false) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(
                    Image(systemName: "eyedropper.halffull")
                        .font(DesignTokens.Typography.sectionHeaderLabel)
                        .foregroundStyle(.secondary)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Circle().inset(by: -8))
        }
        .labelsHidden()
        .disabled(!isInteractive)
        .onChange(of: customColor) { _, color in
            if suppressEcho {
                suppressEcho = false
                return
            }
            // Debounce drag-induced firehose from the system ColorPicker.
            publishTask?.cancel()
            publishTask = Task { [color] in
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                await MainActor.run { onChange(color) }
            }
        }
    }

    /// The swatch closest in hue to the light's colour, when the light is
    /// showing a saturated colour. Bulbs never echo back the exact hex we
    /// sent, so an exact match would almost never show a selection.
    private var selectedSwatch: Color? {
        guard showsSelection else { return nil }
        let current = Self.hsb(value)
        guard current.saturation >= 0.45 else { return nil }
        let nearest = Self.swatches.min { Self.hueDistance(Self.hsb($0).hue, current.hue) < Self.hueDistance(Self.hsb($1).hue, current.hue) }
        guard let nearest, Self.hueDistance(Self.hsb(nearest).hue, current.hue) < 20 else { return nil }
        return nearest
    }

    private func isSelected(_ swatch: Color) -> Bool {
        guard let selectedSwatch else { return false }
        return swatch.hexString == selectedSwatch.hexString
    }

    private static func hsb(_ color: Color) -> (hue: Double, saturation: Double) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue * 360, saturation)
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
}

#Preview {
    LightColorControl(value: .blue, isInteractive: true, onChange: { _ in })
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
}
