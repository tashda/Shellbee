import SwiftUI

@main
struct ShellbeeApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    init() {
        SentryService.shared.start()
    }

    var body: some Scene {
        WindowGroup("Shellbee", for: ShellbeeWindowDestination.self) { $destination in
            ShellbeeSceneView(destination: $destination)
                .environment(environment)
                .preferredColorScheme(appearanceMode.colorScheme)
        } defaultValue: {
            .home
        }
        .commands {
            AppNavigationCommands()
            ShellbeeWindowCommands()
        }
    }
}

private struct ShellbeeWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Menu("Open in New Window") {
                Button("Home") { openWindow(value: ShellbeeWindowDestination.home) }
                Button("Activity") { openWindow(value: ShellbeeWindowDestination.activity) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Network Map") { openWindow(value: ShellbeeWindowDestination.networkMap(bridgeID: nil)) }
                Button("Settings") { openWindow(value: ShellbeeWindowDestination.settings(bridgeID: nil)) }
            }
        }
    }
}

private struct AppNavigationCommands: Commands {
    @FocusedValue(\.appKeyboardActions) private var actions

    var body: some Commands {
        CommandMenu("Navigate") {
            ForEach(Array(AppTab.keyboardSections.enumerated()), id: \.element) { index, section in
                Button(section.title) {
                    actions?.selectSection(section)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                .disabled(actions == nil)
            }

            Divider()

            Button("Search") {
                actions?.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(actions == nil)

            Button("Command Palette") {
                actions?.showCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(actions == nil)
        }
    }
}
