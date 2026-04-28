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
                Text("Interval")
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
        .discardChangesAlert(hasChanges: hasChanges, isPresented: $showingDiscardAlert) { loadFromStore(); dismiss() }
        .reloadOnBridgeInfo(info: environment.store.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
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
        environment.sendBridgeOptions(["health": .object(health)])
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView().environment(AppEnvironment())
    }
}
