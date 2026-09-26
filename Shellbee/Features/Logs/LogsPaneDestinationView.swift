import SwiftUI

struct LogsPaneDestinationView: View {
    let route: LogsPaneRoute

    var body: some View {
        switch route {
        case .activity(let logRoute):
            LogDetailView(bridgeID: logRoute.bridgeID, entry: logRoute.entry)
                .navigationDestination(for: DeviceRoute.self) { deviceRoute in
                    DeviceDetailView(bridgeID: deviceRoute.bridgeID, device: deviceRoute.device)
                }
                .navigationDestination(for: GroupRoute.self) { groupRoute in
                    GroupDetailView(bridgeID: groupRoute.bridgeID, group: groupRoute.group)
                }
        case .bridge(let logRoute):
            BridgeLogDetailView(entry: logRoute.entry)
        }
    }
}
