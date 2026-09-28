import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState

    init(destination: Binding<ShellbeeWindowDestination>) {
        self._destination = destination
        var section = destination.wrappedValue.rootSection
        #if DEBUG
        // Screenshot automation: open a given section on launch
        // (SHELLBEE_SCREENSHOT_SECTION=devices, networkMap, …).
        if let raw = ProcessInfo.processInfo.environment["SHELLBEE_SCREENSHOT_SECTION"],
           let requested = AppTab(rawValue: raw) {
            section = requested
        }
        #endif
        self._navigation = State(initialValue: SceneNavigationState(selectedTab: section))
    }

    var body: some View {
        RootView(windowDestination: destination)
            .environment(\.sceneNavigation, navigation)
            .environment(\.currentWindowDestination, destination)
            .onChange(of: navigation.selectedTab) { _, section in
                destination = section == .home ? .home : .section(section)
            }
    }
}
