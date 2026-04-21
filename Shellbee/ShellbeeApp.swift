import SwiftUI

@main
struct ShellbeeApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
