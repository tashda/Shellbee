import SwiftUI

// Renders [InlineSpan] as a Text backed by AttributedString.
// Uses InlinePresentationIntent for semantic formatting (bold, italic, code)
// so the parent's .font() modifier controls size while formatting is preserved.
// Links are tappable — they open in the default browser via the .link attribute.
struct DocInlineTextView: View {
    let spans: [InlineSpan]
    let sourcePath: String?
    @State private var presentedDestination: InAppDocumentationDestination?

    init(spans: [InlineSpan], sourcePath: String? = nil) {
        self.spans = spans
        self.sourcePath = sourcePath
    }

    var body: some View {
        Text(attributedString)
            .environment(\.openURL, OpenURLAction { url in
                if let destination = DocLinkResolver.destination(for: url) {
                    presentedDestination = destination
                    return .handled
                }
                return .systemAction(url)
            })
            .sheet(item: $presentedDestination) { destination in
                NavigationStack {
                    switch destination {
                    case .touchlinkGuide:
                        TouchlinkGuideView()
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Done") {
                                        presentedDestination = nil
                                    }
                                }
                            }
                    }
                }
            }
    }

    private var attributedString: AttributedString {
        spans.reduce(into: AttributedString()) { result, span in
            switch span {
            case .text(let s):
                result += AttributedString(s)

            case .bold(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .stronglyEmphasized
                result += a

            case .italic(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .emphasized
                result += a

            case .boldItalic(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = [.stronglyEmphasized, .emphasized]
                result += a

            case .code(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .code
                result += a

            case .link(let label, let urlString):
                var a = AttributedString(label)
                a.link = DocLinkResolver.resolvedURL(for: urlString, sourcePath: sourcePath)
                result += a
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        DocInlineTextView(spans: [
            .text("Keep the bulb "),
            .bold("close to the coordinator"),
            .text(" during pairing.")
        ])
        DocInlineTextView(spans: [
            .text("Defaults to "),
            .code("0"),
            .text(" (no transition).")
        ])
        DocInlineTextView(spans: [
            .text("See the "),
            .link(label: "documentation", url: "https://www.zigbee2mqtt.io"),
            .text(" for details.")
        ])
    }
    .font(.subheadline)
    .padding()
}
