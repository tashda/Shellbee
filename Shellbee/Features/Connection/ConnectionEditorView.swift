import SwiftUI

struct ConnectionEditorView: View {
    @Bindable var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ConnectionEditorDraft

    init(viewModel: ConnectionViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.makeEditorDraft())
    }

    var body: some View {
        Form {
            ConnectionServerSection(draft: $draft)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.editorTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Connect") {
                    if viewModel.connect(using: draft) {
                        dismiss()
                    }
                }
                .disabled(!draft.canConnect)
            }
        }
    }
}

#Preview {
    ConnectionEditorView(viewModel: ConnectionViewModel(environment: AppEnvironment()))
}
