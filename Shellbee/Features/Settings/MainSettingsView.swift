import SwiftUI

struct MainSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var logLevel: BridgeSettings.LogLevel = .info
    @State private var lastSeen: BridgeSettings.LastSeenFormat = .disabled
    @State private var elapsed: Bool = false
    @State private var cacheState: Bool = true
    @State private var cacheStatePersistent: Bool = true
    @State private var cacheStateSendOnStartup: Bool = true
    @State private var output: BridgeSettings.OutputFormat = .json
    @State private var timestampFormat: String = "YYYY-MM-DD HH:mm:ss"
    @State private var logRotation: Bool = true
    @State private var logDirectoriesToKeep: Int = 10

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        guard let info = environment.store.bridgeInfo else { return false }
        let advanced = info.config?.advanced
        return logLevel.rawValue != info.logLevel
            || lastSeen.rawValue != (advanced?.lastSeen ?? "disable")
            || elapsed != (advanced?.elapsed ?? false)
            || cacheState != (advanced?.cacheState ?? true)
            || cacheStatePersistent != (advanced?.cacheStatePersistent ?? true)
            || cacheStateSendOnStartup != (advanced?.cacheStateSendOnStartup ?? true)
            || output.rawValue != (advanced?.output ?? "json")
            || timestampFormat != (advanced?.timestampFormat ?? "YYYY-MM-DD HH:mm:ss")
            || logRotation != (advanced?.logRotation ?? true)
            || logDirectoriesToKeep != (advanced?.logDirectoriesToKeep ?? 10)
    }

    private var serverOutputIsAttributeOnly: Bool {
        environment.store.bridgeInfo?.config?.advanced?.output == "attribute"
    }

    var body: some View {
        Form {
            Section {
                Picker("Log Level", selection: $logLevel) {
                    ForEach(BridgeSettings.LogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
            } header: {
                Text("Logging")
            } footer: {
                Text("Controls how verbose the bridge logs are.")
            }

            Section {
                Toggle("Log Rotation", isOn: $logRotation)
                InlineIntField("Directories to Keep", value: $logDirectoriesToKeep, range: 1...50)
            } header: {
                Text("Log Files")
            } footer: {
                Text("Log rotation deletes old log directories automatically. Adjust how many to keep on disk.")
            }

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
        .task { loadFromStore() }
    }

    private func loadFromStore() {
        guard let info = environment.store.bridgeInfo else { return }
        logLevel = BridgeSettings.LogLevel(rawValue: info.logLevel) ?? .info
        let advanced = info.config?.advanced
        lastSeen = BridgeSettings.LastSeenFormat(rawValue: advanced?.lastSeen ?? "disable") ?? .disabled
        elapsed = advanced?.elapsed ?? false
        cacheState = advanced?.cacheState ?? true
        cacheStatePersistent = advanced?.cacheStatePersistent ?? true
        cacheStateSendOnStartup = advanced?.cacheStateSendOnStartup ?? true
        output = BridgeSettings.OutputFormat(rawValue: advanced?.output ?? "json") ?? .json
        timestampFormat = advanced?.timestampFormat ?? "YYYY-MM-DD HH:mm:ss"
        logRotation = advanced?.logRotation ?? true
        logDirectoriesToKeep = advanced?.logDirectoriesToKeep ?? 10
    }

    private func applyChanges() {
        let advanced: [String: JSONValue] = [
            "log_level": .string(logLevel.rawValue),
            "last_seen": .string(lastSeen.rawValue),
            "elapsed": .bool(elapsed),
            "cache_state": .bool(cacheState),
            "cache_state_persistent": .bool(cacheStatePersistent),
            "cache_state_send_on_startup": .bool(cacheStateSendOnStartup),
            "output": .string(output.rawValue),
            "timestamp_format": .string(timestampFormat),
            "log_rotation": .bool(logRotation),
            "log_directories_to_keep": .int(logDirectoriesToKeep)
        ]
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["advanced": .object(advanced)]))
    }
}

#Preview {
    NavigationStack {
        MainSettingsView().environment(AppEnvironment())
    }
}
