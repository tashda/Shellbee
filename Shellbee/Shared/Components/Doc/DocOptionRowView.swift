import SwiftUI

struct DocOptionRowView: View {
    let option: DocOption

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(option.name)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Size.docOptionPaddingV)
                    .background(Color(.quaternarySystemFill), in: Capsule())

                if let type = option.type {
                    Text(type)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Size.docOptionPaddingV)
                        .foregroundStyle(typeColor(type))
                        .background(typeColor(type).opacity(DesignTokens.Opacity.chipFill), in: Capsule())
                }
            }

            if !option.description.isEmpty {
                DocInlineTextView(spans: option.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "boolean": return .green
        case "number": return .blue
        case "enum": return .purple
        case "string": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        DocOptionRowView(option: DocOption(
            name: "transition",
            type: "number",
            description: [.text("Controls transition time in seconds. Defaults to "), .code("0"), .text(".")]
        ))
        DocOptionRowView(option: DocOption(
            name: "color_sync",
            type: "boolean",
            description: [.text("Sync light color when move actions are received.")]
        ))
    }
    .padding()
}
