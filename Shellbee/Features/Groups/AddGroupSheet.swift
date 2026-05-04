import SwiftUI

struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @FocusState private var nameFieldFocused: Bool
    /// `(name, optional id, target bridgeID — nil = focused bridge)`.
    let onConfirm: (String, Int?, UUID?) -> Void

    @State private var name = ""
    @State private var showIDField = false
    @State private var customID = ""
    @State private var bridgeID: UUID?

    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.contains("/")
    }

    var body: some View {
        NavigationStack {
            Form {
                bridgeSection
                Section {
                    TextField("Group Name", text: $name)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                    Toggle("Custom Group ID", isOn: $showIDField)
                    if showIDField {
                        TextField("Group ID (optional)", text: $customID)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Groups let you control multiple devices together.")
                        .textCase(nil)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } footer: {
                    if name.contains("/") {
                        Text("Name cannot contain \"/\"")
                            .foregroundStyle(.red)
                    } else if showIDField {
                        Text("Leave empty to auto-assign the next available ID.")
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Create Group") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    let id = showIDField ? Int(customID) : nil
                    onConfirm(trimmed, id, bridgeID)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .disabled(!isNameValid)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { nameFieldFocused = true }
    }

    @ViewBuilder
    private var bridgeSection: some View {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        if connected.count >= 2 {
            Section {
                BridgePicker(selection: $bridgeID)
            } footer: {
                Text("The group is created on the selected bridge only.")
            }
        }
    }
}

#Preview {
    AddGroupSheet { _, _, _ in }
        .environment(AppEnvironment())
}
