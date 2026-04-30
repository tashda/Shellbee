import SwiftUI

struct OnboardingConnectPage: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ConnectionViewModel?

    var body: some View {
        SwiftUI.Group {
            if let viewModel {
                List {
                    Section {
                        Label {
                            Text("Tap a server below to connect, or use the **+** button to add one manually if your bridge isn't on this network.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.tint)
                        }
                    }
                    ConnectionHistorySection(viewModel: viewModel)
                    ConnectionDiscoverySection(viewModel: viewModel)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.presentNewServer()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Server Manually")
                    }
                }
                .sheet(isPresented: bindingForEditor(viewModel)) {
                    NavigationStack {
                        ConnectionEditorView(viewModel: viewModel)
                    }
                }
                .alert("Connection Error", isPresented: errorBinding(viewModel)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
                .onAppear { viewModel.startDiscovery() }
                .onDisappear { viewModel.stopDiscovery() }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ConnectionViewModel(environment: environment)
            }
        }
    }

    private func bindingForEditor(_ viewModel: ConnectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.isEditorPresented },
            set: { viewModel.isEditorPresented = $0 }
        )
    }

    private func errorBinding(_ viewModel: ConnectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
