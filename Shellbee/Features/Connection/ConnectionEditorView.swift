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

    enum TestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    @Bindable var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ConnectionEditorDraft
    @State private var initialDraft: ConnectionEditorDraft
    @State private var testState: TestState = .idle
    @State private var testTask: Task<Void, Never>?
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
            if let testStatusText {
                Section {
                    Label(testStatusText, systemImage: testStatusIcon)
                        .foregroundStyle(testStatusColor)
                        .font(.subheadline)
                }
            }
            ConnectionServerSection(draft: $draft, focusedField: $focusedField)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .connectionEditorPresentationSizing()
        .navigationTitle(viewModel.editorTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    runConnectionTest()
                } label: {
                    if testState == .testing {
                        ProgressView()
                    } else {
                        Text("Test")
                    }
                }
                .disabled(!canTestConnection)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(actionLabel) {
                    performAction()
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
        .onDisappear {
            testTask?.cancel()
        }
        .onChange(of: draft.host) { _, _ in testState = .idle }
        .onChange(of: draft.port) { _, _ in testState = .idle }
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

    private var canTestConnection: Bool {
        !draft.host.trimmingCharacters(in: .whitespaces).isEmpty && testState != .testing
    }

    private var testStatusText: String? {
        switch testState {
        case .idle: return nil
        case .testing: return "Testing connection…"
        case .success: return "Connection successful"
        case .failure(let message): return message
        }
    }

    private var testStatusIcon: String {
        switch testState {
        case .idle, .testing: return "antenna.radiowaves.left.and.right"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }

    private var testStatusColor: Color {
        switch testState {
        case .idle, .testing: return .secondary
        case .success: return .green
        case .failure: return .red
        }
    }

    /// Commits any in-flight text field edit (notably the token `SecureField`,
    /// whose binding can lag until the field resigns first responder) before
    /// the draft is read for the actual save/connect/test.
    private func commitFocusedField() {
        focusedField = nil
    }

    private func performAction() {
        commitFocusedField()
        DispatchQueue.main.async {
            let succeeded: Bool
            switch mode {
            case .connect:
                succeeded = viewModel.connect(using: draft)
            case .save:
                succeeded = viewModel.save(using: draft)
            }
            if succeeded {
                dismiss()
            }
        }
    }

    private func runConnectionTest() {
        commitFocusedField()
        testTask?.cancel()
        testTask = Task {
            // Let the focus-resign above flush into `draft` before it's read.
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            await MainActor.run { testState = .testing }
            let config = draft.testConfig()
            guard let url = config.webSocketURL else {
                await MainActor.run { testState = .failure("Invalid host or port.") }
                return
            }
            let client = Z2MWebSocketClient()
            do {
                _ = try await client.connect(url: url, allowInvalidCertificates: config.allowInvalidCertificates)
                await client.disconnect()
                guard !Task.isCancelled else { return }
                await MainActor.run { testState = .success }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { testState = .failure(Z2MError.interpret(error)) }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func connectionEditorPresentationSizing() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

#Preview {
    ConnectionEditorView(viewModel: ConnectionViewModel(environment: AppEnvironment()))
}
