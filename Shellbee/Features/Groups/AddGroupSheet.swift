import SwiftUI

struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool
    let onConfirm: (String, Int?) -> Void

    @State private var name = ""
    @State private var showIDField = false
    @State private var customID = ""

    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.contains("/")
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    onConfirm(trimmed, id)
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
}

#Preview {
    AddGroupSheet { _, _ in }
}
