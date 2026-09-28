import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState
    /// Debug screenshot automation only; see `init`.
    private var screenshotDestination: ShellbeeWindowDestination?

    init(destination: Binding<ShellbeeWindowDestination>) {
        self._destination = destination
        var section = destination.wrappedValue.rootSection
        #if DEBUG
        // Screenshot automation: open a given section on launch
        // (SHELLBEE_SCREENSHOT_SECTION=devices, networkMap, …).
        if let raw = ProcessInfo.processInfo.environment["SHELLBEE_SCREENSHOT_SECTION"],
           let requested = AppTab(rawValue: raw) {
            section = requested
            screenshotDestination = requested == .home ? .home : .section(requested)
        }
        #endif
        self._navigation = State(initialValue: SceneNavigationState(selectedTab: section))
    }

    var body: some View {
        RootView(windowDestination: screenshotDestination ?? destination)
            .environment(\.sceneNavigation, navigation)
            .environment(\.currentWindowDestination, destination)
            .onChange(of: navigation.selectedTab) { _, section in
                destination = section == .home ? .home : .section(section)
            }
    }
}
