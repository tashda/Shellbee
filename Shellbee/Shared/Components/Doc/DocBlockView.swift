import SwiftUI

// Renders a single DocBlock. This is the dispatch layer — each case maps
// to either an inline render here (simple blocks) or a dedicated view (complex ones).
// To add a new block type: add a case to DocBlock, then add a rendering branch here.
struct DocBlockView: View {
    let block: DocBlock
    let sourcePath: String?

    init(block: DocBlock, sourcePath: String? = nil) {
        self.block = block
        self.sourcePath = sourcePath
    }

    var body: some View {
        switch block {
        case .paragraph(let spans):
            DocInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .stepList(let steps):
            DocStepListView(steps: steps, sourcePath: sourcePath)

        case .bulletList(let items):
            BulletListView(items: items, sourcePath: sourcePath)

        case .note(let spans):
            DocNoteView(spans: spans, sourcePath: sourcePath)

        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(DesignTokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.secondary.opacity(DesignTokens.Opacity.subtleFill),
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))

        case .table(let table):
            DocTableView(table: table)

        case .optionsList(let options):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(options) { option in
                    DocOptionRowView(option: option, sourcePath: sourcePath)
                    if option.id != options.last?.id { Divider() }
                }
            }

        case .subsection(let title, let blocks):
            SubsectionView(title: title, blocks: blocks, sourcePath: sourcePath)
        }
    }
}

// MARK: - Private helpers

private struct BulletListView: View {
    let items: [[InlineSpan]]
    let sourcePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text("•")
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    DocInlineTextView(spans: spans, sourcePath: sourcePath)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct DocTableView: View {
    let table: DocTable

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(table.headers, id: \.self) { header in
                    Text(header)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
            .background(.secondary.opacity(DesignTokens.Opacity.subtleFill))

            ForEach(Array(table.rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                }
                .background(idx % 2 == 0 ? Color.clear : .secondary.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .stroke(.secondary.opacity(DesignTokens.Opacity.cardStroke))
        }
    }
}

private struct SubsectionView: View {
    let title: String
    let blocks: [DocBlock]
    let sourcePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                DocBlockView(block: block, sourcePath: sourcePath)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            DocBlockView(block: .paragraph([.text("IKEA lights only support transitions on "), .bold("1 attribute"), .text(" at a time.")]))
            DocBlockView(block: .note([.text("Keep the bulb close to the coordinator during pairing.")]))
            DocBlockView(block: .stepList([
                StepItem(number: 1, spans: [.text("Factory reset the light bulb.")]),
                StepItem(number: 2, spans: [.text("After resetting, it will automatically connect.")])
            ]))
            DocBlockView(block: .bulletList([[.text("First item")], [.code("second_item"), .text(" with code")]]))
            DocBlockView(block: .codeBlock("transition: 1\nunfreeze_support: true"))
        }
        .padding()
    }
}
