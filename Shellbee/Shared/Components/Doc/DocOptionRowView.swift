import SwiftUI

/// A device option inside documentation prose: z2m's label with its type in
/// secondary text, then the description.
struct DocOptionRowView: View {
    let option: DocOption
    let sourcePath: String?
    @Environment(\.docContextDevice) private var contextDevice: Device?

    init(option: DocOption, sourcePath: String? = nil) {
        self.option = option
        self.sourcePath = sourcePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text(option.label(in: contextDevice?.definition))
                    .font(.headline)
                if let type = option.typeText {
                    Text(type)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !option.description.isEmpty {
                DocInlineTextView(spans: option.description, sourcePath: sourcePath)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension DocOption {
    /// z2m's label from the device definition when there is one, otherwise
    /// the key humanised the way z2m builds its labels ("color_sync" →
    /// "Color sync").
    func label(in definition: DeviceDefinition?) -> String {
        let match = definition?.options?.first { $0.property == name || $0.name == name }
        if let label = match?.label { return label }
        let words = name.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    var typeText: String? {
        switch type {
        case "number": "Number"
        case "boolean": "On or off"
        case "enum": "Choice"
        case "string": "Text"
        case .some(let other): other.capitalized
        case nil: nil
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
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
