import SwiftUI

struct HomeAssistantSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var bridgeID: UUID? = nil
    private var scope: BridgeScopeBindings { environment.bridgeScope(bridgeID) }

    @State private var enabled: Bool = false
    @State private var discoveryTopic: String = "homeassistant"
    @State private var statusTopic: String = "homeassistant/status"
    @State private var legacyActionSensor: Bool = false
    @State private var experimentalEventEntities: Bool = false

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let ha = scope.bridgeInfo?.config?.homeassistant
        return enabled != (ha?.enabled ?? false)
            || discoveryTopic != (ha?.discoveryTopic ?? "homeassistant")
            || statusTopic != (ha?.statusTopic ?? "homeassistant/status")
            || legacyActionSensor != (ha?.legacyActionSensor ?? false)
            || experimentalEventEntities != (ha?.experimentalEventEntities ?? false)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Home Assistant", isOn: $enabled)
            } footer: {
                Text("Enables native Home Assistant MQTT discovery. Devices will appear automatically in Home Assistant when it is also connected to the same MQTT broker.")
            }

            if enabled {
                Section {
                    SettingsTextField("Discovery Topic", text: $discoveryTopic, placeholder: "homeassistant")
                    SettingsTextField("Status Topic", text: $statusTopic, placeholder: "homeassistant/status")
                } header: {
                    Text("Topics")
                } footer: {
                    Text("Discovery Topic must match the MQTT discovery prefix set in Home Assistant (default: homeassistant). Status Topic is watched to detect when Home Assistant restarts so devices can be re-announced.")
                }

                Section {
                    Toggle("Legacy Action Sensor", isOn: $legacyActionSensor)
                    Toggle("Event Entities", isOn: $experimentalEventEntities)
                } header: {
                    Text("Compatibility")
                } footer: {
                    Text("Legacy Action Sensor creates a sensor entity for button and remote actions (deprecated in newer Home Assistant versions). Event Entities use the newer Home Assistant event model instead.")
                }
            }
        }
        .navigationTitle("Home Assistant")
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
        .reloadOnBridgeInfo(info: scope.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
    }

    private func loadFromStore() {
        let ha = scope.bridgeInfo?.config?.homeassistant
        enabled = ha?.enabled ?? false
        discoveryTopic = ha?.discoveryTopic ?? "homeassistant"
        statusTopic = ha?.statusTopic ?? "homeassistant/status"
        legacyActionSensor = ha?.legacyActionSensor ?? false
        experimentalEventEntities = ha?.experimentalEventEntities ?? false
    }

    private func applyChanges() {
        let ha: [String: JSONValue] = [
            "enabled": .bool(enabled),
            "discovery_topic": .string(discoveryTopic),
            "status_topic": .string(statusTopic),
            "legacy_action_sensor": .bool(legacyActionSensor),
            "experimental_event_entities": .bool(experimentalEventEntities)
        ]
        scope.sendOptions(["homeassistant": .object(ha)])
    }
}

#Preview {
    NavigationStack {
        HomeAssistantSettingsView().environment(AppEnvironment())
    }
}
