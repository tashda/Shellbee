import SwiftUI

struct ShellbeeSceneView: View {
    @Binding var destination: ShellbeeWindowDestination
    @State private var navigation: SceneNavigationState

    init(destination: Binding<ShellbeeWindowDestination>) {
        self._destination = destination
        let section = destination.wrappedValue.rootSection ?? .home
        self._navigation = State(initialValue: SceneNavigationState(selectedTab: section))
    }

    var body: some View {
        RootView(windowDestination: destination)
            .environment(\.sceneNavigation, navigation)
            .onChange(of: navigation.selectedTab) { _, section in
                guard destination.rootSection != nil else { return }
                destination = section == .home ? .home : .section(section)
            }
    }
}

struct RestoredWindowDestinationView: View {
    @Environment(AppEnvironment.self) private var environment
    let destination: ShellbeeWindowDestination

    var body: some View {
        switch destination {
        case .home, .section:
            EmptyView()
        case .device(let bridgeID, let ieeeAddress):
            if let session = environment.registry.session(for: bridgeID),
               let device = session.store.devices.first(where: { $0.ieeeAddress == ieeeAddress }) {
                NavigationStack {
                    DeviceDetailView(bridgeID: bridgeID, device: device)
                }
            } else {
                unavailable("Device Unavailable", systemImage: "sensor.tag.radiowaves.forward")
            }
        case .group(let bridgeID, let groupID):
            if let session = environment.registry.session(for: bridgeID),
               let group = session.store.groups.first(where: { $0.id == groupID }) {
                NavigationStack {
                    GroupDetailView(bridgeID: bridgeID, group: group)
                }
            } else {
                unavailable("Group Unavailable", systemImage: "square.on.square")
            }
        case .activity:
            NavigationStack {
                LogsView()
            }
        case .log(let bridgeID, let entryID):
            if let session = environment.registry.session(for: bridgeID),
               let entry = session.store.logEntries.first(where: { $0.id == entryID }) {
                NavigationStack {
                    LogDetailView(bridgeID: bridgeID, entry: entry)
                }
            } else {
                unavailable("Log Entry Unavailable", systemImage: "list.bullet.rectangle")
            }
        case .settings(let bridgeID):
            NavigationStack {
                if let bridgeID, environment.registry.session(for: bridgeID) != nil {
                    BridgeSettingsView(bridgeID: bridgeID)
                } else {
                    SettingsView(embedInNavigationStack: false)
                }
            }
        case .networkMap(let bridgeID):
            NetworkMapView(initialBridgeID: bridgeID)
        }
    }

    private func unavailable(_ title: String, systemImage: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text("The item was removed or its bridge is unavailable.")
        )
    }
}
