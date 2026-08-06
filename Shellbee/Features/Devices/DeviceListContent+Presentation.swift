import SwiftUI

extension DeviceListContent {
    @ViewBuilder
    var alternativePresentation: some View {
        let devices = presentationDevices()
        DeviceAlternativePresentation(
            mode: presentationMode,
            devices: devices,
            selection: selection,
            viewModel: viewModel,
            onRename: onRename,
            onRemove: onRemove,
            onPendingAlert: onPendingAlert
        )
        .overlay {
            if environment.allDevices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "cpu",
                    description: Text("Devices will appear once a bridge is connected.")
                )
            } else if !viewModel.searchText.isEmpty && devices.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if viewModel.hasActiveFilter && devices.isEmpty {
                ContentUnavailableView(
                    "No Matching Devices",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No devices match \(viewModel.activeFilterDescription).")
                )
            }
        }
    }

    func presentationDevices() -> [BridgeBoundDevice] {
        if isMergedMode {
            return filteredMergedDevices()
        }
        guard let bridgeID = singleBridgeID,
              let session = environment.registry.session(for: bridgeID)
        else { return [] }
        return viewModel.filteredDevices(store: session.store).map {
            BridgeBoundDevice(
                bridgeID: bridgeID,
                bridgeName: session.displayName,
                device: $0
            )
        }
    }
}
