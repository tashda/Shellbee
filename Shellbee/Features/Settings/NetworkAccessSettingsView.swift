import SwiftUI

struct NetworkAccessSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var passlistEntries: [String] = []
    @State private var blocklistEntries: [String] = []
    @State private var newPasslistEntry: String = ""
    @State private var newBlocklistEntry: String = ""
    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let config = environment.store.bridgeInfo?.config
        return passlistEntries != (config?.passlist ?? [])
            || blocklistEntries != (config?.blocklist ?? [])
    }

    var body: some View {
        Form {
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
                Text("Only devices with these addresses may join. Leave empty to allow any device. Swipe left to remove an entry.")
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
                Text("Devices with these addresses are always rejected, even during an active permit-join window. Swipe left to remove.")
            }
        }
        .navigationTitle("Network Access")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
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
        .alert("Discard Unsaved Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) { loadFromStore(); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("Any modifications you have made will be lost.") }
        .task { loadFromStore() }
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
        let config = environment.store.bridgeInfo?.config
        passlistEntries = config?.passlist ?? []
        blocklistEntries = config?.blocklist ?? []
    }

    private func applyChanges() {
        let payload: [String: JSONValue] = [
            "passlist": .array(passlistEntries.map { .string($0) }),
            "blocklist": .array(blocklistEntries.map { .string($0) })
        ]
        environment.send(topic: Z2MTopics.Request.options, payload: .object(payload))
    }
}

#Preview {
    NavigationStack {
        NetworkAccessSettingsView().environment(AppEnvironment())
    }
}
