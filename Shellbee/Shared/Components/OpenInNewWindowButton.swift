import SwiftUI

struct OpenInNewWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    let destination: ShellbeeWindowDestination

    var body: some View {
        if AdaptiveLayout.isPad {
            Button {
                openWindow(value: destination)
            } label: {
                Label("Open in New Window", systemImage: "macwindow.badge.plus")
            }
            .accessibilityIdentifier("open-in-new-window")
        }
    }
}
