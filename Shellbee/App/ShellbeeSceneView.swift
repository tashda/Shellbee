import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState
    /// Debug automation only (screenshots, UI tests); see `init`.
    private var launchDestination: ShellbeeWindowDestination?
    #if DEBUG
    private static var hasStartedUITestLaunch = false
    #endif

    init(destination: Binding<ShellbeeWindowDestination>) {
        self._destination = destination
        var section = destination.wrappedValue.rootSection
        #if DEBUG
        // Screenshot automation: open a given section on launch
        // (SHELLBEE_SCREENSHOT_SECTION=devices, networkMap, …).
        if let raw = ProcessInfo.processInfo.environment["SHELLBEE_SCREENSHOT_SECTION"],
           let requested = AppTab(rawValue: raw) {
            section = requested
            launchDestination = requested == .home ? .home : .section(requested)
        }
        // UI tests: the system restores the window where the previous test
        // left it. Start the launch window at Home; windows a test opens
        // afterwards keep their own destination.
        if ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1", !Self.hasStartedUITestLaunch {
            Self.hasStartedUITestLaunch = true
            section = .home
            launchDestination = .home
        }
        #endif
        self._navigation = State(initialValue: SceneNavigationState(selectedTab: section))
    }

    var body: some View {
        RootView(windowDestination: launchDestination ?? destination)
            .environment(\.sceneNavigation, navigation)
            .environment(\.currentWindowDestination, destination)
            .onChange(of: navigation.selectedTab) { _, section in
                destination = section == .home ? .home : .section(section)
            }
    }
}
