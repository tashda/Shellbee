import SwiftUI

/// One device option in full: its z2m key, type and the complete
/// description from the documentation.
struct DocOptionDetailView: View {
    let option: DocOption
    let label: String
    let sourcePath: String?

    var body: some View {
        List {
            SwiftUI.Group {
                Section {
                    LabeledContent("Key") {
                        Text(option.name)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    if let type = option.typeText {
                        LabeledContent("Type", value: type)
                    }
                }

                if !option.description.isEmpty {
                    Section("Description") {
                        DocInlineTextView(spans: option.description, sourcePath: sourcePath)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .shellbeeThemedCanvas()
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
