import SwiftUI

/// A raw log line in a sheet, opening at half height like the Activity log.
struct RawLogSheet: View {
    let entry: LogEntry

    var body: some View {
        NavigationStack {
            BridgeLogDetailView(entry: entry)
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
