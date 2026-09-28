import SwiftUI

/// A note from the documentation: an info symbol beside the text, or an
/// orange warning triangle when the note warns about something.
struct DocNoteView: View {
    let spans: [InlineSpan]
    let sourcePath: String?

    init(spans: [InlineSpan], sourcePath: String? = nil) {
        self.spans = spans
        self.sourcePath = sourcePath
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            DocNoteSymbol(isWarning: DocNote.isWarning(spans))
            DocInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The leading symbol for a note or a notes row.
struct DocNoteSymbol: View {
    let isWarning: Bool

    var body: some View {
        Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "info.circle")
            .foregroundStyle(isWarning ? AnyShapeStyle(.themedStatus(.orange)) : AnyShapeStyle(.secondary))
            .accessibilityLabel(isWarning ? "Warning" : "Note")
    }
}

enum DocNote {
    private static let warningWords = ["warning", "caution", "do not", "don't", "never", "danger", "will brick", "irreversible"]

    /// True when the text warns rather than informs.
    static func isWarning(_ spans: [InlineSpan]) -> Bool {
        let text = DeviceDocNormalizer.plainText(spans).lowercased()
        return warningWords.contains { text.contains($0) }
    }

    static func isWarning(_ blocks: [DocBlock]) -> Bool {
        blocks.contains { block in
            switch block {
            case .note(let spans), .paragraph(let spans): isWarning(spans)
            case .subsection(_, let inner): isWarning(inner)
            default: false
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
        DocNoteView(spans: [.text("Keep the bulb "), .bold("close to the coordinator"), .text(" while pairing.")])
        DocNoteView(spans: [.text("Don't run a Touchlink reset with a Hue bridge nearby.")])
    }
    .padding()
}
