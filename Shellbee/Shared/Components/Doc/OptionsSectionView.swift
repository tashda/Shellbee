import SwiftUI

// Renders the "Options" section with a structured list of property rows.
// The options list is detected automatically by DocParser (backtick-named bullet items).
// Non-option blocks (intro paragraphs, links) are rendered normally by DocBlockView.
struct OptionsSectionView: View {
    let section: DocSection

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SectionHeader(title: section.title)

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .optionsList(let options):
                    optionsList(options)
                default:
                    DocBlockView(block: block)
                }
            }
        }
    }

    // No card background — the outer section card (DeviceDocView) provides the grouping.
    private func optionsList(_ options: [DocOption]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options) { option in
                DocOptionRowView(option: option)
                    .padding(DesignTokens.Spacing.md)
                if option.id != options.last?.id {
                    Divider().padding(.leading, DesignTokens.Spacing.md)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        OptionsSectionView(section: DocSection(
            title: "Options",
            level: 2,
            blocks: [
                .paragraph([
                    .italic("[How to use device type specific configuration]"),
                    .text(".")
                ]),
                .optionsList([
                    DocOption(name: "transition", type: "number", description: [
                        .text("Controls the transition time in seconds. Defaults to "), .code("0"), .text(".")
                    ]),
                    DocOption(name: "color_sync", type: "boolean", description: [
                        .text("Sync color when move actions are received.")
                    ]),
                    DocOption(name: "unfreeze_support", type: "boolean", description: [
                        .text("Whether to unfreeze IKEA lights before sending commands.")
                    ])
                ])
            ]
        ))
        .padding()
    }
}
