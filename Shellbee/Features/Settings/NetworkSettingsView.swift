import SwiftUI

struct NetworkSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var channel: Int = 11
    @State private var transmitPower: String = ""
    @State private var adapterConcurrent: String = ""
    @State private var adapterDelay: String = ""

    @State private var showingDiscardAlert = false
    @State private var showingDangerConfirm = false

    private var hasChanges: Bool {
        let adv = environment.store.bridgeInfo?.config?.advanced
        let storedChannel = environment.store.bridgeInfo?.network?.channel ?? (adv?.channel ?? 11)
        return channel != storedChannel
            || transmitPower != optionalIntString(adv?.transmitPower)
            || adapterConcurrent != optionalIntString(adv?.adapterConcurrent)
            || adapterDelay != optionalIntString(adv?.adapterDelay)
    }

    var body: some View {
        Form {
            Section {
                SettingsWarningBanner(
                    message: "Changing the Zigbee channel or PAN ID causes all paired devices to lose connection and require re-pairing.",
                    severity: .danger
                )
            }

            Section {
                LabeledContent("Zigbee Channel") {
                    Picker("Channel", selection: $channel) {
                        ForEach(11...26, id: \.self) { ch in
                            Text("\(ch)").tag(ch)
                        }
                    }
                    .labelsHidden()
                }
            } header: {
                Text("RF Channel")
            } footer: {
                Text("Zigbee 2.4 GHz channels 11–26. Recommended: 15, 20, or 25 for minimal Wi-Fi interference. Requires bridge restart and re-pairing all devices.")
            }

            Section {
                numericField("Transmit Power (dBm)", text: $transmitPower, placeholder: "Default")
                numericField("Adapter Concurrent (threads)", text: $adapterConcurrent, placeholder: "Default")
                numericField("Adapter Message Delay (ms)", text: $adapterDelay, placeholder: "Default")
            } header: {
                Text("Hardware Tuning")
            } footer: {
                Text("Leave blank to use bridge defaults. Transmit power affects range. Concurrent/delay affect how fast commands are sent to the adapter.")
            }
        }
        .navigationTitle("Network & Hardware")
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
        .alert("Apply Network Settings?", isPresented: $showingDangerConfirm) {
            Button("Apply — I understand", role: .destructive) { applyChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing the Zigbee channel will disconnect all paired devices.")
        }
        .task { loadFromStore() }
    }

    private func numericField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
        }
    }

    private func optionalIntString(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private func loadFromStore() {
        let adv = environment.store.bridgeInfo?.config?.advanced
        channel = environment.store.bridgeInfo?.network?.channel ?? adv?.channel ?? 11
        transmitPower = optionalIntString(adv?.transmitPower)
        adapterConcurrent = optionalIntString(adv?.adapterConcurrent)
        adapterDelay = optionalIntString(adv?.adapterDelay)
    }

    private func applyChanges() {
        var advanced: [String: JSONValue] = ["channel": .int(channel)]
        if let v = Int(transmitPower) { advanced["transmit_power"] = .int(v) }
        if let v = Int(adapterConcurrent) { advanced["adapter_concurrent"] = .int(v) }
        if let v = Int(adapterDelay) { advanced["adapter_delay"] = .int(v) }
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["advanced": .object(advanced)]))
    }
}

#Preview {
    NavigationStack {
        NetworkSettingsView().environment(AppEnvironment())
    }
}
