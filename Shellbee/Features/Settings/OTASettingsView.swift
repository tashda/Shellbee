import SwiftUI

struct OTASettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var updateCheckInterval: Int = 1440
    @State private var disableAutomaticUpdateCheck: Bool = false
    @State private var overrideIndexLocation: String = ""
    @State private var imageBlockRequestTimeout: Int = 150000
    @State private var imageBlockResponseDelay: Int = 250
    @State private var defaultMaximumDataSize: Int = 50

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let ota = environment.store.bridgeInfo?.config?.ota
        return updateCheckInterval != (ota?.updateCheckInterval ?? 1440)
            || disableAutomaticUpdateCheck != (ota?.disableAutomaticUpdateCheck ?? false)
            || overrideIndexLocation != (ota?.zigbeeOtaOverrideIndexLocation ?? "")
            || imageBlockRequestTimeout != (ota?.imageBlockRequestTimeout ?? 150000)
            || imageBlockResponseDelay != (ota?.imageBlockResponseDelay ?? 250)
            || defaultMaximumDataSize != (ota?.defaultMaximumDataSize ?? 50)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Disable Automatic Checks", isOn: $disableAutomaticUpdateCheck)
                if !disableAutomaticUpdateCheck {
                    InlineIntField("Check Interval", value: $updateCheckInterval, unit: "min", range: 60...43200)
                }
            } header: {
                Text("Automatic Updates")
            } footer: {
                Text("When enabled, the bridge checks for firmware updates on a schedule. Default is every 1,440 minutes (24 hours).")
            }

            Section {
                LabeledContent("Index URL") {
                    TextField("Optional", text: $overrideIndexLocation)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Firmware Index")
            } footer: {
                Text("Override the default Zigbee OTA firmware index with a custom URL or local path. Leave empty to use the official index.")
            }

            Section {
                InlineIntField("Transfer Request Timeout", value: $imageBlockRequestTimeout, unit: "ms", range: 10000...600000)
                InlineIntField("Delay Between Blocks", value: $imageBlockResponseDelay, unit: "ms", range: 0...5000)
                InlineIntField("Block Size", value: $defaultMaximumDataSize, unit: "bytes", range: 10...100)
            } header: {
                Text("Transfer Timing")
            } footer: {
                Text("Advanced transfer settings. Request Timeout is how long to wait for each block response (default 150,000 ms). Delay adds a pause between blocks to reduce load. Block Size controls how many bytes are sent per block (default 50).")
            }
        }
        .navigationTitle("OTA Updates")
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
        let ota = environment.store.bridgeInfo?.config?.ota
        updateCheckInterval = ota?.updateCheckInterval ?? 1440
        disableAutomaticUpdateCheck = ota?.disableAutomaticUpdateCheck ?? false
        overrideIndexLocation = ota?.zigbeeOtaOverrideIndexLocation ?? ""
        imageBlockRequestTimeout = ota?.imageBlockRequestTimeout ?? 150000
        imageBlockResponseDelay = ota?.imageBlockResponseDelay ?? 250
        defaultMaximumDataSize = ota?.defaultMaximumDataSize ?? 50
    }

    private func applyChanges() {
        var ota: [String: JSONValue] = [
            "update_check_interval": .int(updateCheckInterval),
            "disable_automatic_update_check": .bool(disableAutomaticUpdateCheck),
            "image_block_request_timeout": .int(imageBlockRequestTimeout),
            "image_block_response_delay": .int(imageBlockResponseDelay),
            "default_maximum_data_size": .int(defaultMaximumDataSize)
        ]
        if !overrideIndexLocation.isEmpty { ota["zigbee_ota_override_index_location"] = .string(overrideIndexLocation) }
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["ota": .object(ota)]))
    }
}

#Preview {
    NavigationStack {
        OTASettingsView().environment(AppEnvironment())
    }
}
