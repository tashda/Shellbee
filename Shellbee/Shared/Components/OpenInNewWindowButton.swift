import SwiftUI

struct OpenInNewWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.currentWindowDestination) private var currentWindowDestination
    let destination: ShellbeeWindowDestination

    var body: some View {
        if AdaptiveLayout.isPad, currentWindowDestination != destination {
            Button {
                openWindow(value: destination)
            } label: {
                Label("Open in New Window", systemImage: "macwindow.badge.plus")
            }
            .accessibilityIdentifier("open-in-new-window")
        }
    }
}
