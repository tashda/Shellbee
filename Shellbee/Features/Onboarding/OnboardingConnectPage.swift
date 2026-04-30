import SwiftUI

struct OnboardingConnectPage: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ConnectionViewModel?
    @State private var draft = ConnectionEditorDraft()
    let onConnectTapped: () -> Void

    var body: some View {
        Form {
            Section {
                Text("Find your broker URL in Z2M's frontend at Settings → MQTT, or in your `configuration.yaml`. If your bridge is on the same network, the discovery scan on the previous screen would have found it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ConnectionServerSection(draft: $draft)

            Section {
                Button {
                    if let viewModel, viewModel.connect(using: draft) {
                        onConnectTapped()
                    }
                } label: {
                    Label("Connect", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!draft.canConnect)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("If Z2M auth is enabled, paste the token from `configuration.yaml` under `frontend.auth_token`. Leave blank if auth isn't configured.")
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            if viewModel == nil {
                viewModel = ConnectionViewModel(environment: environment)
            }
        }
    }
}
