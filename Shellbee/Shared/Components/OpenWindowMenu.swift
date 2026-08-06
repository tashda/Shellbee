import SwiftUI

struct OpenWindowMenu: View {
    @Environment(\.openWindow) private var openWindow
    let currentDestination: ShellbeeWindowDestination

    var body: some View {
        if AdaptiveLayout.isPad {
            Menu {
                Button("Current View") { openWindow(value: currentDestination) }
                Button("Home") { openWindow(value: ShellbeeWindowDestination.home) }
                Button("Activity") { openWindow(value: ShellbeeWindowDestination.activity) }
                    .accessibilityIdentifier("open-window-activity")
                Button("Network Map") {
                    openWindow(value: ShellbeeWindowDestination.networkMap(bridgeID: nil))
                }
                Button("Settings") {
                    openWindow(value: ShellbeeWindowDestination.settings(bridgeID: nil))
                }
            } label: {
                Label("Open Window", systemImage: "macwindow.badge.plus")
            }
            .accessibilityIdentifier("open-window-menu")
        }
    }
}
