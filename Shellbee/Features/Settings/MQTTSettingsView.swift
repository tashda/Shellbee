import SwiftUI

struct MQTTSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var server: String = ""
    @State private var baseTopic: String = "zigbee2mqtt"
    @State private var clientID: String = "zigbee2mqtt"
    @State private var user: String = ""
    @State private var password: String = ""
    @State private var version: Int = 4
    @State private var keepalive: Int = 60
    @State private var ca: String = ""
    @State private var cert: String = ""
    @State private var key: String = ""
    @State private var rejectUnauthorized: Bool = true
    @State private var includeDeviceInformation: Bool = false
    @State private var forceDisableRetain: Bool = false
    @State private var maximumPacketSize: Int = 1048576
    @State private var qos: Int = 0

    @State private var showingDiscardAlert = false
    @State private var showingEmptyPasswordAlert = false

    private var hasChanges: Bool {
        guard let mqtt = environment.store.bridgeInfo?.config?.mqtt else { return false }
        return server != (mqtt.server ?? "")
            || baseTopic != (mqtt.baseTopic ?? "zigbee2mqtt")
            || clientID != (mqtt.clientID ?? "zigbee2mqtt")
            || user != (mqtt.user ?? "")
            || password != ""
            || version != (mqtt.version ?? 4)
            || keepalive != (mqtt.keepalive ?? 60)
            || ca != (mqtt.ca ?? "")
            || cert != (mqtt.cert ?? "")
            || key != (mqtt.key ?? "")
            || rejectUnauthorized != (mqtt.rejectUnauthorized ?? true)
            || includeDeviceInformation != (mqtt.includeDeviceInformation ?? false)
            || forceDisableRetain != (mqtt.forceDisableRetain ?? false)
            || maximumPacketSize != (mqtt.maximumPacketSize ?? 1048576)
            || qos != (mqtt.qos ?? 0)
    }

    var body: some View {
        Form {
            Section {
                SettingsTextField("Server URL", text: $server, placeholder: "mqtt://localhost:1883")
                SettingsTextField("Base Topic", text: $baseTopic, placeholder: "zigbee2mqtt")
            } header: {
                Text("Broker Connection")
            } footer: {
                Text("Updating connection settings may cause the bridge to temporarily disconnect while applying the changes.")
            }

            Section {
                SettingsTextField("Client ID", text: $clientID, placeholder: "zigbee2mqtt")
                SettingsTextField("Username", text: $user, placeholder: "Optional")

                LabeledContent("Password") {
                    SecureField("Optional", text: $password)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Authentication")
            }

            Section {
                SettingsTextField("CA Certificate", text: $ca, placeholder: "Absolute path")
                SettingsTextField("Client Certificate", text: $cert, placeholder: "Absolute path")
                SettingsTextField("Client Key", text: $key, placeholder: "Absolute path")

                Toggle("Reject Untrusted Certificates", isOn: $rejectUnauthorized)
            } header: {
                Text("SSL / TLS")
            }

            Section {
                InlineIntField("Keepalive Interval", value: $keepalive, unit: "s", range: 10...3600)

                Picker("Protocol Version", selection: $version) {
                    Text("v3.1.1 (v4)").tag(4)
                    Text("v5.0 (v5)").tag(5)
                }
            } header: {
                Text("Protocol Options")
            }

            Section {
                Toggle("Include Device Metadata", isOn: $includeDeviceInformation)
                Toggle("Disable Message Retain", isOn: $forceDisableRetain)

                Picker("QoS Level", selection: $qos) {
                    Text("QoS 0 — At most once").tag(0)
                    Text("QoS 1 — At least once").tag(1)
                    Text("QoS 2 — Exactly once").tag(2)
                }

                LabeledContent("Max Packet Size (bytes)") {
                    TextField("1048576", value: $maximumPacketSize, format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Include Device Metadata adds model and vendor info to every state message. Disabling retain means the broker won't store the last state for new subscribers.")
            }
        }
        .navigationTitle("MQTT")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    if password.isEmpty { showingEmptyPasswordAlert = true }
                    else { applyChanges() }
                }
                .disabled(!hasChanges)
            }
        }
        .discardChangesAlert(hasChanges: hasChanges, isPresented: $showingDiscardAlert) { loadFromStore(); dismiss() }
        .alert("No Password Provided", isPresented: $showingEmptyPasswordAlert) {
            Button("Apply Anyway", role: .destructive) { applyChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Applying these changes with an empty password may remove existing credentials from the server. Do you want to proceed?")
        }
        .reloadOnBridgeInfo(info: environment.store.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
    }

    private func applyChanges() {
        updateOptions()
        password = ""
    }

    private func loadFromStore() {
        guard let mqtt = environment.store.bridgeInfo?.config?.mqtt else { return }
        server = mqtt.server ?? ""
        baseTopic = mqtt.baseTopic ?? "zigbee2mqtt"
        clientID = mqtt.clientID ?? "zigbee2mqtt"
        user = mqtt.user ?? ""
        password = ""
        version = mqtt.version ?? 4
        keepalive = mqtt.keepalive ?? 60
        ca = mqtt.ca ?? ""
        cert = mqtt.cert ?? ""
        key = mqtt.key ?? ""
        rejectUnauthorized = mqtt.rejectUnauthorized ?? true
        includeDeviceInformation = mqtt.includeDeviceInformation ?? false
        forceDisableRetain = mqtt.forceDisableRetain ?? false
        maximumPacketSize = mqtt.maximumPacketSize ?? 1048576
        qos = mqtt.qos ?? 0
    }

    private func updateOptions() {
        let mqtt: [String: JSONValue] = [
            "server": .string(server),
            "base_topic": .string(baseTopic),
            "client_id": .string(clientID),
            "user": .string(user),
            "password": .string(password),
            "version": .int(version),
            "keepalive": .int(keepalive),
            "ca": .string(ca),
            "cert": .string(cert),
            "key": .string(key),
            "reject_unauthorized": .bool(rejectUnauthorized),
            "include_device_information": .bool(includeDeviceInformation),
            "force_disable_retain": .bool(forceDisableRetain),
            "maximum_packet_size": .int(maximumPacketSize),
            "qos": .int(qos)
        ]
        environment.sendBridgeOptions(["mqtt": .object(mqtt)])
    }
}

#Preview {
    NavigationStack {
        MQTTSettingsView().environment(AppEnvironment())
    }
}
