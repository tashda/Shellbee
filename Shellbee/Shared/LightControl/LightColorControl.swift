import SwiftUI

struct LightColorControl: View {
    let value: Color
    let isInteractive: Bool
    let onChange: (Color) -> Void

    @State private var customColor: Color

    private static let swatches: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .cyan, .blue, .purple, .pink
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)
    private static let swatchSize: CGFloat = 36

    init(value: Color, isInteractive: Bool, onChange: @escaping (Color) -> Void) {
        self.value = value
        self.isInteractive = isInteractive
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
        .onChange(of: value) { _, newValue in customColor = newValue }
    }

    private func swatchButton(_ color: Color) -> some View {
        Button { onChange(color) } label: {
            Circle()
                .fill(color)
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .overlay(Circle().strokeBorder(isSelected(color) ? Color.primary : Color.clear, lineWidth: 2))
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Circle().inset(by: -8))
        }
        .labelsHidden()
        .disabled(!isInteractive)
        .onChange(of: customColor) { _, color in onChange(color) }
    }

    private func isSelected(_ swatch: Color) -> Bool {
        swatch.hexString == value.hexString
    }
}

#Preview {
    LightColorControl(value: .blue, isInteractive: true, onChange: { _ in })
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
}
