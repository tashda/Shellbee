import SwiftUI

struct AvailabilitySettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool = false
    @State private var activeTimeout: Int = 10
    @State private var activeMaxJitter: Int = 0
    @State private var activeBackoff: Bool = false
    @State private var activePauseOnBackoffGt: Int = 0
    @State private var passiveTimeout: Int = 1500

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        guard let av = environment.store.bridgeInfo?.config?.availability else {
            return enabled != false || activeTimeout != 10 || passiveTimeout != 1500
        }
        return enabled != (av.enabled ?? false)
            || activeTimeout != (av.active?.timeout ?? 10)
            || activeMaxJitter != (av.active?.maxJitter ?? 0)
            || activeBackoff != (av.active?.backoff ?? false)
            || activePauseOnBackoffGt != (av.active?.pauseOnBackoffGt ?? 0)
            || passiveTimeout != (av.passive?.timeout ?? 1500)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Track Device Availability", isOn: $enabled)
            } footer: {
                Text("When enabled, Shellbee tracks whether each device is online or offline. Mains-powered devices use a short timeout; battery-powered devices use a longer one.")
            }

            if enabled {
                Section {
                    InlineIntField("Offline Timeout", value: $activeTimeout, unit: "min", range: 1...60)
                    Toggle("Retry with Backoff", isOn: $activeBackoff)
                    if activeBackoff {
                        InlineIntField("Pause After Retries", value: $activePauseOnBackoffGt, unit: "retries", range: 0...20)
                    }
                    InlineIntField("Max Jitter", value: $activeMaxJitter, unit: "ms", range: 0...60000)
                } header: {
                    Text("Mains-Powered Devices")
                } footer: {
                    Text("Time in minutes before a mains-powered device is considered offline. Backoff reduces check frequency when a device is consistently offline. Jitter spreads out reconnection attempts to avoid overloading the network.")
                }

                Section {
                    InlineIntField("Offline Timeout", value: $passiveTimeout, unit: "min", range: 60...10000)
                } header: {
                    Text("Battery-Powered Devices")
                } footer: {
                    Text("Time in minutes before a battery-powered device is considered offline. Should be longer than the device's reporting interval.")
                }
            }
        }
        .navigationTitle("Availability")
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
        let av = environment.store.bridgeInfo?.config?.availability
        enabled = av?.enabled ?? false
        activeTimeout = av?.active?.timeout ?? 10
        activeMaxJitter = av?.active?.maxJitter ?? 0
        activeBackoff = av?.active?.backoff ?? false
        activePauseOnBackoffGt = av?.active?.pauseOnBackoffGt ?? 0
        passiveTimeout = av?.passive?.timeout ?? 1500
    }

    private func applyChanges() {
        var activePayload: [String: JSONValue] = [
            "timeout": .int(activeTimeout),
            "backoff": .bool(activeBackoff)
        ]
        if activeMaxJitter > 0 { activePayload["max_jitter"] = .int(activeMaxJitter) }
        if activeBackoff && activePauseOnBackoffGt > 0 {
            activePayload["pause_on_backoff_gt"] = .int(activePauseOnBackoffGt)
        }
        let payload: [String: JSONValue] = [
            "availability": .object([
                "enabled": .bool(enabled),
                "active": .object(activePayload),
                "passive": .object(["timeout": .int(passiveTimeout)])
            ])
        ]
        environment.send(topic: Z2MTopics.Request.options, payload: .object(payload))
    }
}

#Preview {
    NavigationStack {
        AvailabilitySettingsView().environment(AppEnvironment())
    }
}
