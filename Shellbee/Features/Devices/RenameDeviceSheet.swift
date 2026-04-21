import SwiftUI

struct RenameDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let onConfirm: (String, Bool) -> Void

    @State private var newName: String
    @State private var updateHomeAssistant = true

    init(device: Device, onConfirm: @escaping (String, Bool) -> Void) {
        self.device = device
        self.onConfirm = onConfirm
        _newName = State(initialValue: device.friendlyName)
    }

    private var canSave: Bool { !newName.isEmpty && newName != device.friendlyName }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        DeviceImageView(
                            device: device,
                            isAvailable: true,
                            size: DesignTokens.Size.deviceActionSheetImage
                        )
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(device.friendlyName)
                                .font(.headline)
                            Text(device.definition?.model ?? "Unknown Model")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("New name", text: $newName)
                        .submitLabel(.done)
                        .onSubmit { saveIfPossible() }
                    Toggle("Home Assistant Entity ID", isOn: $updateHomeAssistant)
                } footer: {
                    if updateHomeAssistant {
                        Text("Also updates the Home Assistant entity ID to match the new name.")
                    }
                }
            }
            .navigationTitle("Rename Device")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var actionBar: some View {
        Button("Save Changes") {
            saveIfPossible()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .disabled(!canSave)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    private func saveIfPossible() {
        guard canSave else { return }
        onConfirm(newName, updateHomeAssistant)
        dismiss()
    }
}

#Preview {
    RenameDeviceSheet(device: .preview) { _, _ in }
}
