import SwiftUI

@main
struct ShellbeeApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(ShellbeeTheme.storageKey) private var themeRawValue = ShellbeeTheme.defaultTheme.rawValue
    @AppStorage(StatusTone.themedStorageKey) private var themesStatusColors = false
    @AppStorage(ShellbeeTheme.surfaceTintKey) private var surfaceTint = ShellbeeTheme.defaultSurfaceTint

    private var theme: ShellbeeTheme { ShellbeeTheme.stored(themeRawValue) }

    init() {
        SentryService.shared.start()
        HomeCardKind.applyDefaultsOnce()
        #if DEBUG
        // XCUITest waits for the app to go idle before every action; with
        // a live bridge redrawing constantly it may never go idle, and each
        // action then stalls for a minute. UI tests check behaviour, not
        // motion, so they run without animations.
        if ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1" {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("Shellbee", for: ShellbeeWindowDestination.self) { $destination in
            ShellbeeSceneView(destination: $destination)
                .configuredTopScrollEdgeEffect()
                .environment(environment)
                .preferredColorScheme(appearanceMode.colorScheme)
                .environment(\.shellbeeTheme, theme)
                .environment(\.shellbeeThemesStatusColors, themesStatusColors)
                .environment(\.shellbeeSurfaceTint, surfaceTint)
                .shellbeeWindowTint(theme)
                .onChange(of: LiveActivityAppearance(theme: theme, surfaceTint: surfaceTint,
                                                     themesIndicators: themesStatusColors)) { _, _ in
                    LiveActivityAppearance.refreshRunningActivities()
                }
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
