import SwiftUI

struct SettingsWorkspaceDestinationView: View {
    let route: SettingsWorkspaceRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .bridgeOverview(let id): BridgeSettingsView(bridgeID: id)
        case .bridgeConnection(let id): ServerDetailView(bridgeID: id)
        case .bridgeGeneral(let id): MainSettingsView(bridgeID: id)
        case .mqtt(let id): MQTTSettingsView(bridgeID: id)
        case .adapter(let id): SerialSettingsView(bridgeID: id)
        case .logOutput(let id): LogOutputView(bridgeID: id)
        case .homeAssistant(let id): HomeAssistantSettingsView(bridgeID: id)
        case .availability(let id): AvailabilitySettingsView(bridgeID: id)
        case .ota(let id): OTASettingsView(bridgeID: id)
        case .health(let id): HealthSettingsView(bridgeID: id)
        case .network(let id): NetworkSettingsView(bridgeID: id)
        case .deviceFiltering(let id): NetworkAccessSettingsView(bridgeID: id)
        case .touchlink(let id): TouchlinkView(bridgeID: id)
        case .backup(let id): BackupView(bridgeID: id)
        case .appGeneral: AppGeneralView()
        case .liveActivities: AppLiveActivitiesView()
        case .notifications: AppNotificationSettingsView()
        case .deviceLibrary: DocBrowserView()
        case .about: AboutView()
        case .developer: DeveloperSettingsView()
        }
    }
}
