import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState
    /// Debug automation only (screenshots, UI tests); see `init`.
    private var launchDestination: ShellbeeWindowDestination?
    #if DEBUG
    @Environment(\.dismissWindow) private var dismissWindow
    private static var uiTestLaunchDate: Date?
    /// A window iPadOS restored from a previous UI test, closed on appear.
    private var isLeftoverUITestWindow = false
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
        // UI tests: iPadOS restores every window where the previous test
        // left it. Start the first window at Home and close any other window
        // restored at launch; windows a test opens later (never within the
        // first seconds) keep their own destination.
        if ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1" {
            if let launched = Self.uiTestLaunchDate {
                isLeftoverUITestWindow = Date().timeIntervalSince(launched) < 3
            } else {
                Self.uiTestLaunchDate = Date()
                section = .home
                launchDestination = .home
            }
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
            #if DEBUG
            .onAppear {
                if isLeftoverUITestWindow { dismissWindow() }
            }
            #endif
    }
}
