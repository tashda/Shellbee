import SwiftUI

struct MainSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var lastSeen: BridgeSettings.LastSeenFormat = .disabled
    @State private var elapsed: Bool = false
    @State private var cacheState: Bool = true
    @State private var cacheStatePersistent: Bool = true
    @State private var cacheStateSendOnStartup: Bool = true
    @State private var output: BridgeSettings.OutputFormat = .json
    @State private var timestampFormat: String = "YYYY-MM-DD HH:mm:ss"

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        guard let info = environment.store.bridgeInfo else { return false }
        let advanced = info.config?.advanced
        return lastSeen.rawValue != (advanced?.lastSeen ?? "disable")
            || elapsed != (advanced?.elapsed ?? false)
            || cacheState != (advanced?.cacheState ?? true)
            || cacheStatePersistent != (advanced?.cacheStatePersistent ?? true)
            || cacheStateSendOnStartup != (advanced?.cacheStateSendOnStartup ?? true)
            || output.rawValue != (advanced?.output ?? "json")
            || timestampFormat != (advanced?.timestampFormat ?? "YYYY-MM-DD HH:mm:ss")
    }

    private var serverOutputIsAttributeOnly: Bool {
        environment.store.bridgeInfo?.config?.advanced?.output == "attribute"
    }

    var body: some View {
        Form {
            Section {
                Picker("Last Seen Format", selection: $lastSeen) {
                    ForEach(BridgeSettings.LastSeenFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                Toggle("Show Elapsed Time", isOn: $elapsed)
                LabeledContent("Timestamp Format") {
                    TextField("YYYY-MM-DD HH:mm:ss", text: $timestampFormat)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.caption.monospaced())
                }
            } header: {
                Text("Timestamps")
            } footer: {
                Text("Last Seen adds a timestamp to device state messages. Elapsed Time shows the duration between consecutive messages from the same device.")
            }

            Section {
                Toggle("Cache Device State", isOn: $cacheState)
                if cacheState {
                    Toggle("Keep Cache Between Restarts", isOn: $cacheStatePersistent)
                    Toggle("Publish Cached State on Startup", isOn: $cacheStateSendOnStartup)
                }
            } header: {
                Text("State Caching")
            } footer: {
                Text("Caching sends all device properties in every state message, even unchanged ones. Recommended if you use Home Assistant. Keep Cache Between Restarts saves this data across bridge restarts.")
            }

            Section {
                if serverOutputIsAttributeOnly {
                    SettingsWarningBanner(
                        message: "Your Zigbee2MQTT server is set to Attribute-only output. Shellbee requires JSON to display device states — change to JSON or Both below and tap Apply.",
                        severity: .caution
                    )
                }
                Picker("Output Format", selection: $output) {
                    Text(BridgeSettings.OutputFormat.json.label).tag(BridgeSettings.OutputFormat.json)
                    Text(BridgeSettings.OutputFormat.attributeAndJson.label).tag(BridgeSettings.OutputFormat.attributeAndJson)
                }
            } header: {
                Text("Output")
            } footer: {
                Text("JSON publishes all device properties in a single message. Both adds a separate per-topic message for each property alongside JSON. Shellbee requires JSON to be included.")
            }
        }
        .navigationTitle("General")
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
        guard let info = environment.store.bridgeInfo else { return }
        let advanced = info.config?.advanced
        lastSeen = BridgeSettings.LastSeenFormat(rawValue: advanced?.lastSeen ?? "disable") ?? .disabled
        elapsed = advanced?.elapsed ?? false
        cacheState = advanced?.cacheState ?? true
        cacheStatePersistent = advanced?.cacheStatePersistent ?? true
        cacheStateSendOnStartup = advanced?.cacheStateSendOnStartup ?? true
        output = BridgeSettings.OutputFormat(rawValue: advanced?.output ?? "json") ?? .json
        timestampFormat = advanced?.timestampFormat ?? "YYYY-MM-DD HH:mm:ss"
    }

    private func applyChanges() {
        guard let info = environment.store.bridgeInfo else { return }
        let advanced = info.config?.advanced
        var changes: [String: JSONValue] = [:]

        if lastSeen.rawValue != (advanced?.lastSeen ?? "disable") {
            changes["last_seen"] = .string(lastSeen.rawValue)
        }
        if elapsed != (advanced?.elapsed ?? false) {
            changes["elapsed"] = .bool(elapsed)
        }
        if cacheState != (advanced?.cacheState ?? true) {
            changes["cache_state"] = .bool(cacheState)
        }
        if cacheStatePersistent != (advanced?.cacheStatePersistent ?? true) {
            changes["cache_state_persistent"] = .bool(cacheStatePersistent)
        }
        if cacheStateSendOnStartup != (advanced?.cacheStateSendOnStartup ?? true) {
            changes["cache_state_send_on_startup"] = .bool(cacheStateSendOnStartup)
        }
        if output.rawValue != (advanced?.output ?? "json") {
            changes["output"] = .string(output.rawValue)
        }
        if timestampFormat != (advanced?.timestampFormat ?? "YYYY-MM-DD HH:mm:ss") {
            changes["timestamp_format"] = .string(timestampFormat)
        }

        guard !changes.isEmpty else { return }
        environment.sendBridgeOptions(["advanced": .object(changes)])
    }
}

#Preview {
    NavigationStack {
        MainSettingsView().environment(AppEnvironment())
    }
}
