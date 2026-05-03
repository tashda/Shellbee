import SwiftUI

struct NetworkAccessSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var bridgeID: UUID? = nil
    private var scope: BridgeScopeBindings { environment.bridgeScope(bridgeID) }

    @State private var passlistEntries: [String] = []
    @State private var blocklistEntries: [String] = []
    @State private var newPasslistEntry: String = ""
    @State private var newBlocklistEntry: String = ""
    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let config = scope.bridgeInfo?.config
        return passlistEntries != (config?.passlist ?? [])
            || blocklistEntries != (config?.blocklist ?? [])
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "lock.shield.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Device Filtering")
                            .font(.headline)
                        Text("Control which Zigbee devices are allowed to join your network by IEEE address. An empty Allow List permits any device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                ForEach(passlistEntries, id: \.self) { entry in
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                }
                .onDelete { passlistEntries.remove(atOffsets: $0) }
                HStack {
                    TextField("0x0000000000000000", text: $newPasslistEntry)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                        .submitLabel(.done)
                        .onSubmit { addPasslistEntry() }
                    Button(action: addPasslistEntry) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(newPasslistEntry.isEmpty)
                }
            } header: {
                Text("Allow List")
            } footer: {
                Text("Leave empty to allow any device to join.")
            }

            Section {
                ForEach(blocklistEntries, id: \.self) { entry in
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                }
                .onDelete { blocklistEntries.remove(atOffsets: $0) }
                HStack {
                    TextField("0x0000000000000000", text: $newBlocklistEntry)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                        .submitLabel(.done)
                        .onSubmit { addBlocklistEntry() }
                    Button(action: addBlocklistEntry) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(newBlocklistEntry.isEmpty)
                }
            } header: {
                Text("Block List")
            } footer: {
                Text("Devices here are always rejected, even during an active join window.")
            }
        }
        .navigationTitle("Device Filtering")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
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

    private func addPasslistEntry() {
        let trimmed = newPasslistEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !passlistEntries.contains(trimmed) else { return }
        passlistEntries.append(trimmed)
        newPasslistEntry = ""
    }

    private func addBlocklistEntry() {
        let trimmed = newBlocklistEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !blocklistEntries.contains(trimmed) else { return }
        blocklistEntries.append(trimmed)
        newBlocklistEntry = ""
    }

    private func loadFromStore() {
        let config = scope.bridgeInfo?.config
        passlistEntries = config?.passlist ?? []
        blocklistEntries = config?.blocklist ?? []
    }

    private func applyChanges() {
        let payload: [String: JSONValue] = [
            "passlist": .array(passlistEntries.map { .string($0) }),
            "blocklist": .array(blocklistEntries.map { .string($0) })
        ]
        scope.sendOptions(payload)
    }
}

#Preview {
    NavigationStack {
        NetworkAccessSettingsView().environment(AppEnvironment())
    }
}
