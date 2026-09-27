import SwiftUI

struct AddSceneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool
    let onConfirm: (String) -> Void

    @State private var name = ""

    private var isNameValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Group {
                    Section {
                        TextField("Scene Name", text: $name)
                            .focused($nameFieldFocused)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("Saves the current group light state as a named scene.")
                    }
                }
                .shellbeeThemedRows()
            }
            .shellbeeThemedCanvas()
            .navigationTitle("Save Scene")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Save Scene") {
                    onConfirm(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(.sheetAction)
                .disabled(!isNameValid)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .shellbeeThemedBar()
            }
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
        .task { nameFieldFocused = true }
    }
}

#Preview {
    AddSceneSheet { _ in }
}
