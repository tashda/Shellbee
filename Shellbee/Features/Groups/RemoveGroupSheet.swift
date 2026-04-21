import SwiftUI

struct RemoveGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: Group
    let onConfirm: (Bool) -> Void

    @State private var forceRemove = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: DesignTokens.Size.deviceActionSheetImage, height: DesignTokens.Size.deviceActionSheetImage)
                            .background(.red.opacity(DesignTokens.Opacity.chipFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(group.friendlyName)
                                .font(.headline)
                            Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Force Remove", isOn: $forceRemove)
                } footer: {
                    if forceRemove {
                        Text("Force remove deletes the group even if the bridge cannot reach all members.")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Remove Group")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Remove Group", role: .destructive) {
                    onConfirm(forceRemove)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    RemoveGroupSheet(group: .previewWithMembers) { _ in }
}
