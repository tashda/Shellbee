import SwiftUI

struct ConnectionEditorView: View {
    enum Field: Hashable {
        case name
        case host
        case port
        case basePath
        case authToken
    }

    enum Mode {
        /// Bottom action saves and connects. Used by the first-launch onboarding
        /// flow and the legacy connection screen.
        case connect
        /// Bottom action saves the bridge to the saved-bridges list without
        /// connecting. Used by the Saved Bridges screen's "Add" path so users
        /// can register additional bridges without disrupting the active session.
        case save
    }

    @Bindable var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ConnectionEditorDraft
    @State private var initialDraft: ConnectionEditorDraft
    @FocusState private var focusedField: Field?
    private let mode: Mode

    init(viewModel: ConnectionViewModel, mode: Mode = .connect) {
        self.viewModel = viewModel
        self.mode = mode
        let initial = viewModel.makeEditorDraft()
        _draft = State(initialValue: initial)
        _initialDraft = State(initialValue: initial)
    }

    var body: some View {
        Form {
            ConnectionServerSection(draft: $draft, focusedField: $focusedField)
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
                Button(actionLabel) {
                    if viewModel.connect(using: draft) {
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .disabled(!isActionEnabled)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .name
            }
        }
    }

    private var actionLabel: String {
        switch mode {
        case .connect: "Connect"
        case .save: "Save"
        }
    }

    private var isActionEnabled: Bool {
        switch mode {
        case .connect:
            return draft.canConnect
        case .save:
            return draft.canConnect && draft.normalizedForComparison() != initialDraft.normalizedForComparison()
        }
    }
}

#Preview {
    ConnectionEditorView(viewModel: ConnectionViewModel(environment: AppEnvironment()))
}
