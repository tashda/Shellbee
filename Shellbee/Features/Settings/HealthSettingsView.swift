import SwiftUI

struct HealthSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var interval: Int = 30
    @State private var resetOnCheck: Bool = false
    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let health = environment.store.bridgeInfo?.config?.health
        return interval != (health?.interval ?? 30)
            || resetOnCheck != (health?.resetOnCheck ?? false)
    }

    var body: some View {
        Form {
            Section {
                InlineIntField("Check Interval", value: $interval, unit: "min", range: 0...120)
            } header: {
                Text("Health Check Interval")
            } footer: {
                Text("How often the bridge checks its own health. Set to 0 to disable health checks entirely.")
            }

            Section {
                Toggle("Reset Adapter on Each Check", isOn: $resetOnCheck)
            } footer: {
                Text("When enabled, the bridge adapter is reset each time the health check runs. Only enable if you experience reliability issues.")
            }
        }
        .navigationTitle("Health Checks")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { applyChanges() }
                    .disabled(!hasChanges)
            }
        }
        .alert("Discard Unsaved Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) { loadFromStore(); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("Any modifications you have made will be lost.") }
        .task { loadFromStore() }
    }

    private func loadFromStore() {
        let health = environment.store.bridgeInfo?.config?.health
        interval = health?.interval ?? 30
        resetOnCheck = health?.resetOnCheck ?? false
    }

    private func applyChanges() {
        let health: [String: JSONValue] = [
            "interval": .int(interval),
            "reset_on_check": .bool(resetOnCheck)
        ]
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["health": .object(health)]))
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView().environment(AppEnvironment())
    }
}
