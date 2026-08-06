import SwiftUI

@main
struct ShellbeeApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    init() {
        SentryService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .commands {
            AppNavigationCommands()
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
