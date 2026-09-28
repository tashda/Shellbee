import SwiftUI

/// A `DeviceListRow` that reads its device's state itself, through
/// `DeviceLiveState`, so a report from one device redraws that row only
/// instead of the whole list.
struct LiveDeviceListRow: View {
    let device: Device
    let store: AppStore
    let bridgeID: UUID
    let bridgeName: String
    let viewModel: DeviceListViewModel
    let onRename: (BridgeBoundDevice) -> Void
    let onRemove: (BridgeBoundDevice) -> Void
    let onPendingAlert: (PendingDeviceAlert, UUID) -> Void

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let name = device.friendlyName
        let live = store.liveState(for: name)
        let state = live.state
        let bound = BridgeBoundDevice(bridgeID: bridgeID, bridgeName: bridgeName, device: device)
        DeviceListRow(
            device: device,
            state: state,
            isAvailable: store.liveAvailabilityStatus(for: name, live: live).isAvailable,
            otaStatus: store.liveOTAStatus(for: name, live: live),
            checkResult: store.deviceCheckResults[name],
            isDeleting: store.pendingRemovals.contains(name),
            isIdentifying: store.identifyInProgress.contains(name),
            bridgeID: bridgeID,
            bridgeName: bridgeName,
            onRename: { onRename(bound) },
            onRemove: { onRemove(bound) },
            onReconfigure: { onPendingAlert(.reconfigure(device), bridgeID) },
            onInterview: { onPendingAlert(.interview(device), bridgeID) },
            onIdentify: { environment.scope(for: bridgeID).identifyDevice(name) },
            onUpdate: state.hasUpdateAvailable
                ? { viewModel.updateDevice(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            onCheckUpdate: { viewModel.checkDeviceUpdate(device, environment: environment, bridgeID: bridgeID) },
            onSchedule: state.hasUpdateAvailable
                ? { viewModel.scheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            onUnschedule: { viewModel.unscheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
        )
    }
}
