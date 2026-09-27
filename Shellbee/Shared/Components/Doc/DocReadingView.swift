import SwiftUI

/// A documentation section as prose on the themed canvas, kept to a
/// readable width on iPad.
struct DocReadingView: View {
    let title: String
    let blocks: [DocBlock]
    let sourcePath: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    DocBlockView(block: block, sourcePath: sourcePath)
                }
            }
            .frame(maxWidth: DesignTokens.Size.readableContentMaxWidth, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .shellbeeThemedCanvas(fallback: Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
