import SwiftUI

extension View {
    /// Shared actions for the Connection/Server card row. Keep this aligned
    /// across single-bridge and per-bridge Settings flows.
    func connectionCardActions(
        config: ConnectionConfig,
        onEdit: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        self
            .contextMenu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
    }
}
