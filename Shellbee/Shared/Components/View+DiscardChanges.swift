import SwiftUI

extension View {
    func discardChangesAlert(
        hasChanges: Bool,
        isPresented: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        self
            .navigationBarBackButtonHidden(hasChanges)
            .alert("Discard Unsaved Changes?", isPresented: isPresented) {
                Button("Discard Changes", role: .destructive, action: onDiscard)
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Any modifications you have made will be lost.")
            }
    }
}
