import SwiftUI

/// Navigation intents belong to a scene, not to the shared bridge runtime.
/// Keeping them here prevents a selection or notification tap in one window
/// from moving every other Shellbee window.
@Observable
final class SceneNavigationState {
    var selectedTab: AppTab
    var selectedBridgeID: UUID?
    var pendingDeviceFilter: DeviceQuickFilter?
    var pendingLogSheet: LogSheetRequest?
    var pendingDeviceNavigation: DeviceRoute?
    var pendingGroupNavigation: GroupRoute?
    var pendingSettingsNavigation: BridgeSettingsRoute?
    var pendingNetworkMapBridgeID: UUID?
    var pendingNetworkMapRefreshBridgeID: UUID?

    init(selectedTab: AppTab = .home, selectedBridgeID: UUID? = nil) {
        self.selectedTab = selectedTab
        self.selectedBridgeID = selectedBridgeID
    }
}

private struct SceneNavigationStateKey: EnvironmentKey {
    static let defaultValue = SceneNavigationState()
}

extension EnvironmentValues {
    var sceneNavigation: SceneNavigationState {
        get { self[SceneNavigationStateKey.self] }
        set { self[SceneNavigationStateKey.self] = newValue }
    }
}
