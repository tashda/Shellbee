import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState

    init(destination: Binding<ShellbeeWindowDestination>) {
        self._destination = destination
        let section = destination.wrappedValue.rootSection
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
