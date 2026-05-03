import SwiftUI

struct CopyableRow: View {
    @Environment(AppEnvironment.self) private var environment
    let label: String
    let value: String

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            // Phase 1 multi-bridge: fast-track notifications are scanned across
            // every connected bridge by the overlay, so enqueueing on any
            // session's store surfaces the banner. Use the first connected
            // session as a stable target — selection-following would race.
            if let store = environment.registry.orderedSessions.first(where: \.isConnected)?.store {
                store.enqueueNotification(
                    InAppNotification(level: .info, title: "Copied to Clipboard", priority: .fastTrack)
                )
            }
        } label: {
            LabeledContent(label, value: value)
        }
        .buttonStyle(.plain)
    }
}
