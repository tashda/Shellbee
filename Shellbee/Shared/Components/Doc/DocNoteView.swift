import SwiftUI

struct DocNoteView: View {
    let spans: [InlineSpan]
    let sourcePath: String?

    init(spans: [InlineSpan], sourcePath: String? = nil) {
        self.spans = spans
        self.sourcePath = sourcePath
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.noteBar)
                .fill(.tint)
                .frame(width: DesignTokens.Size.docNoteBarWidth)
                .padding(.vertical, DesignTokens.Spacing.summaryRowVerticalPadding)

            DocInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
    }
}

#Preview {
    VStack(spacing: 16) {
        DocNoteView(spans: [
            .text("Keep the bulb "),
            .bold("close to the coordinator"),
            .text(" (adapter) while pairing.")
        ])
        DocNoteView(spans: [
            .text("Use very short on/off cycles — start with the bulb on, then: off, on ×6.")
        ])
    }
    .padding()
    .tint(.blue)
}
