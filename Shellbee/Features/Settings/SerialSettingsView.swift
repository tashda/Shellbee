import SwiftUI

struct SerialSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var port: String = ""
    @State private var adapter: String = ""
    @State private var baudrate: Int = 115200
    @State private var rtscts: Bool = false
    @State private var disableLed: Bool = false

    @State private var showingDiscardAlert = false
    @State private var showingDangerConfirm = false

    private var hasChanges: Bool {
        let serial = environment.store.bridgeInfo?.config?.serial
        return port != (serial?.port ?? "")
            || adapter != (serial?.adapter ?? "")
            || baudrate != (serial?.baudrate ?? 115200)
            || rtscts != (serial?.rtscts ?? false)
            || disableLed != (serial?.disableLed ?? false)
    }

    private let adapterOptions = ["", "zstack", "ezsp", "deconz", "zigate", "zboss", "ember"]

    var body: some View {
        Form {
            Section {
                SettingsWarningBanner(
                    message: "Changes here can prevent the bridge from connecting to the Zigbee adapter. Proceed only if you know what you are doing.",
                    severity: .danger
                )
            }

            Section {
                SettingsTextField("Serial Port", text: $port, placeholder: "/dev/ttyUSB0")
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
                Text("Adapter")
            } footer: {
                Text("Enter the device path for your Zigbee adapter (e.g. /dev/ttyUSB0). Leave Adapter Type on Auto-detect unless your adapter requires a specific driver.")
            }

            Section {
                Toggle("Disable Adapter LED", isOn: $disableLed)
            } header: {
                Text("Hardware")
            } footer: {
                Text("Disables the LED on the Zigbee adapter if supported.")
            }
        }
        .navigationTitle("Adapter")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { showingDangerConfirm = true }
                    .disabled(!hasChanges)
            }
        }
        .alert("Discard Unsaved Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) { loadFromStore(); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("Any modifications you have made will be lost.") }
        .alert("Apply Adapter Settings?", isPresented: $showingDangerConfirm) {
            Button("Apply — I understand the risk", role: .destructive) { applyChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing serial settings requires a bridge restart and may break the Zigbee adapter connection.")
        }
        .task { loadFromStore() }
    }

    private func loadFromStore() {
        let serial = environment.store.bridgeInfo?.config?.serial
        port = serial?.port ?? ""
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
        if !port.isEmpty { serial["port"] = .string(port) }
        if !adapter.isEmpty { serial["adapter"] = .string(adapter) }
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["serial": .object(serial)]))
    }
}

#Preview {
    NavigationStack {
        SerialSettingsView().environment(AppEnvironment())
    }
}
