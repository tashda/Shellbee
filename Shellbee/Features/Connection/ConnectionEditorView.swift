import SwiftUI

struct ConnectionEditorView: View {
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
    private let mode: Mode

    init(viewModel: ConnectionViewModel, mode: Mode = .connect) {
        self.viewModel = viewModel
        self.mode = mode
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
        }
        .safeAreaInset(edge: .bottom) {
            Button(actionLabel) {
                let success: Bool
                switch mode {
                case .connect:
                    success = viewModel.connect(using: draft)
                case .save:
                    success = viewModel.save(using: draft)
                }
                if success { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .disabled(!draft.canConnect)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
    }

    private var actionLabel: String {
        switch mode {
        case .connect: "Connect"
        case .save: "Save"
        }
    }
}

#Preview {
    ConnectionEditorView(viewModel: ConnectionViewModel(environment: AppEnvironment()))
}
