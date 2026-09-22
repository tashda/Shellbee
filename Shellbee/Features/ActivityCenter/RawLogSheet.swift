import SwiftUI

/// A raw log line in a sheet, opening at half height like the Activity log.
struct RawLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: LogEntry

    var body: some View {
        NavigationStack {
            BridgeLogDetailView(entry: entry, doneAction: { dismiss() })
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
