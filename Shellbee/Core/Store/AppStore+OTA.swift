import Foundation

extension AppStore {
    var activeOTAUpdates: [OTAUpdateStatus] {
        otaUpdates.values.filter(\.isActive)
    }

    func otaStatus(for friendlyName: String) -> OTAUpdateStatus? {
        otaUpdates[friendlyName] ?? state(for: friendlyName).otaUpdateStatus(for: friendlyName)
    }

    func startOTAUpdate(for friendlyName: String) {
        otaUpdates[friendlyName] = OTAUpdateStatus(
            deviceName: friendlyName,
            phase: .requested,
            progress: nil,
            remaining: nil
        )
        OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices, bridgeID: activeBridgeID, bridgeDisplayName: activeBridgeName)
    }

    func startOTACheck(for friendlyName: String) {
        otaUpdates[friendlyName] = OTAUpdateStatus(
            deviceName: friendlyName,
            phase: .checking,
            progress: nil,
            remaining: nil
        )
    }

    func startOTASchedule(for friendlyName: String) {
        otaUpdates[friendlyName] = OTAUpdateStatus(
            deviceName: friendlyName,
            phase: .scheduled,
            progress: nil,
            remaining: nil
        )
    }

    func cancelOTASchedule(for friendlyName: String) {
        if otaUpdates[friendlyName]?.phase == .scheduled {
            otaUpdates.removeValue(forKey: friendlyName)
        }
    }

    func handleOTAState(for deviceName: String, state: [String: JSONValue]) {
        guard let update = state.otaUpdateStatus(for: deviceName) else { return }

        let previous = otaUpdates[deviceName]

        switch update.phase {
        case .available:
            if previous?.isActive == true {
                otaUpdates.removeValue(forKey: deviceName)
            }
        case .checking:
            break // Handled by manual check trigger
        case .requested:
            otaUpdates[deviceName] = update
        case .scheduled, .updating:
            otaUpdates[deviceName] = update
        case .idle:
            otaUpdates.removeValue(forKey: deviceName)
            if previous?.isActive == true, activeOTAUpdates.isEmpty {
                OTAUpdateLiveActivityCoordinator.shared.finish(for: deviceName, success: true, bridgeID: activeBridgeID)
                return
            }
        }

        OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices, bridgeID: activeBridgeID, bridgeDisplayName: activeBridgeName)
    }

    func handleOTAResponse(_ response: DeviceOTAUpdateResponse) {
        if let deviceName = response.deviceName {
            otaResponseForwarding?(deviceName, response.isSuccess, .update)
        }
        guard !response.isSuccess else { return }
        guard let deviceName = response.deviceName else { return }

        otaUpdates.removeValue(forKey: deviceName)

        if activeOTAUpdates.isEmpty {
            OTAUpdateLiveActivityCoordinator.shared.finish(for: deviceName, success: false, bridgeID: activeBridgeID)
        } else {
            OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices, bridgeID: activeBridgeID, bridgeDisplayName: activeBridgeName)
        }
    }

    func handleOTACheckResponse(_ response: DeviceOTAUpdateResponse) {
        guard let deviceName = response.deviceName else { return }

        otaResponseForwarding?(deviceName, response.isSuccess, .check)

        if !response.isSuccess {
            flashCheckResult(.failed, for: deviceName)
            Task {
                try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivitySuccess))
                await MainActor.run {
                    if otaUpdates[deviceName]?.phase == .checking {
                        otaUpdates.removeValue(forKey: deviceName)
                    }
                }
            }
        } else {
            if otaUpdates[deviceName]?.phase == .checking {
                otaUpdates.removeValue(forKey: deviceName)
            }
            // The subsequent deviceState event decides whether an update was
            // found. Look at current state: if hasUpdateAvailable, "Found
            // update"; otherwise "No update" (off by default as a
            // notification, but always shown as a transient row chip).
            let hasUpdate = state(for: deviceName).hasUpdateAvailable
            if hasUpdate {
                flashCheckResult(.updateFound, for: deviceName)
            } else {
                flashCheckResult(.noUpdate, for: deviceName)
                enqueueNotification(InAppNotification(
                    level: .info,
                    title: "No Update Available",
                    subtitle: deviceName,
                    deviceName: deviceName,
                    category: .otaNoUpdate
                ))
            }
        }
    }

    func flashCheckResult(_ result: DeviceCheckResult, for deviceName: String) {
        deviceCheckResults[deviceName] = result
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.checkResultDisplay))
            await MainActor.run {
                guard let self else { return }
                if self.deviceCheckResults[deviceName] == result {
                    self.deviceCheckResults.removeValue(forKey: deviceName)
                }
            }
        }
    }
}
