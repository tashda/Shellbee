import SwiftUI

struct CopyableRow: View {
    @Environment(AppEnvironment.self) private var environment
    let label: String
    let value: String

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            environment.store.pendingNotifications.append(
                InAppNotification(level: .info, title: "Copied to Clipboard", subtitle: value)
            )
        } label: {
            LabeledContent(label, value: value)
        }
        .buttonStyle(.plain)
    }
}
