import SwiftUI

struct RenameGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: Group
    let onConfirm: (String) -> Void

    @State private var newName: String

    init(group: Group, onConfirm: @escaping (String) -> Void) {
        self.group = group
        self.onConfirm = onConfirm
        _newName = State(initialValue: group.friendlyName)
    }

    private var canSave: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != group.friendlyName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: DesignTokens.Size.deviceActionSheetImage, height: DesignTokens.Size.deviceActionSheetImage)
                            .background(Color.accentColor.opacity(DesignTokens.Opacity.accentFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(group.friendlyName)
                                .font(.headline)
                            Text("Group #\(group.id)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("New name", text: $newName)
                        .submitLabel(.done)
                        .onSubmit { saveIfPossible() }
                }
            }
            .navigationTitle("Rename Group")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
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
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func saveIfPossible() {
        guard canSave else { return }
        onConfirm(newName.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}

#Preview {
    RenameGroupSheet(group: .preview) { _ in }
}
