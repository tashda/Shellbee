import SwiftUI

struct SerialSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var adapter: String = ""
    @State private var baudrate: Int = 115200
    @State private var rtscts: Bool = false
    @State private var disableLed: Bool = false

    @State private var showingDiscardAlert = false
    @State private var showingApplyConfirm = false

    private var currentPort: String {
        environment.store.bridgeInfo?.config?.serial?.port ?? ""
    }

    private var hasChanges: Bool {
        let serial = environment.store.bridgeInfo?.config?.serial
        return adapter != (serial?.adapter ?? "")
            || baudrate != (serial?.baudrate ?? 115200)
            || rtscts != (serial?.rtscts ?? false)
            || disableLed != (serial?.disableLed ?? false)
    }

    private let adapterOptions = ["", "zstack", "ezsp", "deconz", "zigate", "zboss", "ember"]

    var body: some View {
        Form {
            Section {
                if currentPort.isEmpty {
                    LabeledContent("Serial Port", value: "Not configured")
                } else {
                    CopyableRow(label: "Serial Port", value: currentPort)
                }
                LabeledContent("Adapter Type") {
                    Picker("Adapter", selection: $adapter) {
                        Text("Auto-detect").tag("")
                        ForEach(adapterOptions.dropFirst(), id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .labelsHidden()
                }
                Picker("Baud Rate", selection: $baudrate) {
                    Text("115200").tag(115200)
                    Text("57600").tag(57600)
                    Text("38400").tag(38400)
                }
                Toggle("RTS/CTS Flow Control", isOn: $rtscts)
            } header: {
                Text("Connection")
            } footer: {
                Text("The serial port is read-only and can only be changed in Zigbee2MQTT directly.")
            }

            Section {
                Toggle("Adapter LED", isOn: Binding(
                    get: { !disableLed },
                    set: { disableLed = !$0 }
                ))
            } header: {
                Text("Hardware")
            } footer: {
                Text("Controls the indicator LED on the Zigbee adapter, if supported.")
            }
        }
        .navigationTitle("Adapter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { showingApplyConfirm = true }
                    .disabled(!hasChanges)
            }
        }
        .discardChangesAlert(hasChanges: hasChanges, isPresented: $showingDiscardAlert) { loadFromStore(); dismiss() }
        .alert("Apply Adapter Settings?", isPresented: $showingApplyConfirm) {
            Button("Apply", role: .destructive) { applyChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing adapter settings requires a bridge restart.")
        }
        .reloadOnBridgeInfo(info: environment.store.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
    }

    private func loadFromStore() {
        let serial = environment.store.bridgeInfo?.config?.serial
        adapter = serial?.adapter ?? ""
        baudrate = serial?.baudrate ?? 115200
        rtscts = serial?.rtscts ?? false
        disableLed = serial?.disableLed ?? false
    }

    private func applyChanges() {
        var serial: [String: JSONValue] = [
            "rtscts": .bool(rtscts),
            "disable_led": .bool(disableLed),
            "baudrate": .int(baudrate)
        ]
        if !adapter.isEmpty { serial["adapter"] = .string(adapter) }
        environment.sendBridgeOptions(["serial": .object(serial)])
    }
}

#Preview {
    NavigationStack {
        SerialSettingsView().environment(AppEnvironment())
    }
}
