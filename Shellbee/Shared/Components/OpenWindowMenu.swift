import SwiftUI

struct OpenWindowMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.currentWindowDestination) private var currentWindowDestination
    let currentDestination: ShellbeeWindowDestination

    var body: some View {
        if AdaptiveLayout.isPad {
            Menu {
                if currentWindowDestination != currentDestination {
                    Button("Current View") { openWindow(value: currentDestination) }
                }
                if currentWindowDestination != .home {
                    Button("Home") { openWindow(value: ShellbeeWindowDestination.home) }
                }
                if currentWindowDestination != .activity {
                    Button("Activity") { openWindow(value: ShellbeeWindowDestination.activity) }
                        .accessibilityIdentifier("open-window-activity")
                }
                if currentWindowDestination != .networkMap(bridgeID: nil) {
                    Button("Network Map") {
                        openWindow(value: ShellbeeWindowDestination.networkMap(bridgeID: nil))
                    }
                }
                if currentWindowDestination != .settings(bridgeID: nil) {
                    Button("Settings") {
                        openWindow(value: ShellbeeWindowDestination.settings(bridgeID: nil))
                    }
                }
            } label: {
                Label("Open Window", systemImage: "macwindow.badge.plus")
            }
            .accessibilityIdentifier("open-window-menu")
        }
    }
}
