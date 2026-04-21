import SwiftUI

struct ConnectionOverviewView: View {
    @Bindable var viewModel: ConnectionViewModel

    var body: some View {
        NavigationStack {
            List {
                ConnectionHistorySection(viewModel: viewModel)
                ConnectionDiscoverySection(viewModel: viewModel)
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isConnecting {
                        Button("Cancel", role: .destructive) {
                            Task { await viewModel.cancel() }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.presentNewServer()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
            }
            .alert("Connection Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.isEditorPresented) {
                NavigationStack {
                    ConnectionEditorView(viewModel: viewModel)
                }
            }
            .onDisappear { viewModel.stopDiscovery() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    ConnectionOverviewView(viewModel: ConnectionViewModel(environment: AppEnvironment()))
}
