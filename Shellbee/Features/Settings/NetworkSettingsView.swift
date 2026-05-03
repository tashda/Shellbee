import SwiftUI

struct NetworkSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var bridgeID: UUID? = nil
    private var scope: BridgeScopeBindings { environment.bridgeScope(bridgeID) }

    @State private var transmitPower: String = ""
    @State private var adapterConcurrent: String = ""
    @State private var adapterDelay: String = ""

    @State private var showingDiscardAlert = false

    private var currentChannel: Int {
        let adv = scope.bridgeInfo?.config?.advanced
        return scope.bridgeInfo?.network?.channel ?? adv?.channel ?? 11
    }

    private var hasChanges: Bool {
        let adv = scope.bridgeInfo?.config?.advanced
        return transmitPower != optionalIntString(adv?.transmitPower)
            || adapterConcurrent != optionalIntString(adv?.adapterConcurrent)
            || adapterDelay != optionalIntString(adv?.adapterDelay)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Zigbee Channel", value: "\(currentChannel)")
            } header: {
                Text("RF Channel")
            } footer: {
                Text("To change the Zigbee channel, use the Zigbee2MQTT web interface. Changing it causes all paired devices to lose connection and require re-pairing.")
            }

            Section {
                numericField("Transmit Power", text: $transmitPower, placeholder: "Default", unit: "dBm")
                numericField("Concurrency", text: $adapterConcurrent, placeholder: "Default", unit: "threads")
                numericField("Message Delay", text: $adapterDelay, placeholder: "Default", unit: "ms")
            } header: {
                Text("Adapter Tuning")
            } footer: {
                Text("Leave blank to use bridge defaults. Transmit power affects range. Concurrency and message delay affect how fast commands are sent to the adapter.")
            }
        }
        .navigationTitle("Network & Hardware")
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

    private func numericField(_ label: String, text: Binding<String>, placeholder: String, unit: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                TextField(placeholder, text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func optionalIntString(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private func loadFromStore() {
        let adv = scope.bridgeInfo?.config?.advanced
        transmitPower = optionalIntString(adv?.transmitPower)
        adapterConcurrent = optionalIntString(adv?.adapterConcurrent)
        adapterDelay = optionalIntString(adv?.adapterDelay)
    }

    private func applyChanges() {
        var advanced: [String: JSONValue] = [:]
        if let v = Int(transmitPower) { advanced["transmit_power"] = .int(v) }
        if let v = Int(adapterConcurrent) { advanced["adapter_concurrent"] = .int(v) }
        if let v = Int(adapterDelay) { advanced["adapter_delay"] = .int(v) }
        scope.sendOptions(["advanced": .object(advanced)])
    }
}

#Preview {
    NavigationStack {
        NetworkSettingsView().environment(AppEnvironment())
    }
}
