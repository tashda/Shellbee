import SwiftUI

struct FilterChip: View {
    let label: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    HStack {
        FilterChip(label: "Lights", systemImage: "lightbulb.fill", isSelected: true) {}
        FilterChip(label: "Sensors", systemImage: "sensor.fill", isSelected: false) {}
    }
    .padding()
}
