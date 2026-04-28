import Foundation

extension AppStore {
    func apply(_ event: Z2MEvent) {
        switch event {
        case .bridgeInfo(let info):
            bridgeInfo = info
        case .bridgeState(let state):
            bridgeOnline = state == "online"
        case .devices(let list):
            // Backfill first-seen for any device we've never recorded.
            // Covers the case where a device joined while the app was closed
            // and we missed the bridge/event device_joined message — when it
            // shows up in interview state on the first snapshot, treat it as
            // freshly added.
            for device in list where device.type != .coordinator {
                guard deviceFirstSeen[device.ieeeAddress] == nil else { continue }
                if device.interviewing || !device.interviewCompleted {
                    recordFirstSeen(ieee: device.ieeeAddress)
                }
            }
            devices = list
        case .groups(let list):
            groups = list
        case .logMessage(let msg):
            let level = LogLevel(raw: msg.level) ?? .info
            insertRawLogEntry(LogEntry(
                id: msg.id, timestamp: .now, level: level,
                category: .general, namespace: msg.namespace,
                message: msg.message, deviceName: nil
            ))
            let knownNames = Set(devices.map(\.friendlyName) + groups.map(\.friendlyName))
            let ctx = LogMapperEngine.context(
                message: msg.message, namespace: msg.namespace, knownDevices: knownNames
            )
            // MQTT publish for a known device/group state topic is redundant — the
            // .deviceState event creates a richer stateChange entry for the same update.
            if case .mqttPublish = ctx.action,
               let deviceName = ctx.primaryDevice?.friendlyName,
               knownNames.contains(deviceName) {
                break
            }
            let entry = LogEntry(
                id: msg.id, timestamp: .now, level: level,
                category: ctx.inferredCategory,
                namespace: msg.namespace, message: msg.message,
                deviceName: ctx.primaryDevice?.friendlyName, context: ctx
            )
            insertLogEntry(entry)
            if let note = notification(for: ctx.action, level: level, deviceName: ctx.primaryDevice?.friendlyName, message: msg.message, id: msg.id) {
                enqueueNotification(note)
            }
        case .bridgeEvent(let event):
            if let entry = Self.logEntry(from: event) {
                insertLogEntry(entry)
                if let note = Self.notification(from: event, entry: entry) {
                    enqueueNotification(note)
                }
            }
            if let ieee = event.data.object?["ieee_address"]?.stringValue {
                switch event.type {
                case "device_joined":
                    // Restart the 30-min window on (re)join.
                    recordFirstSeen(ieee: ieee, overwrite: true)
                case "device_leave":
                    removeFirstSeen(ieee: ieee)
                case "device_interview":
                    let name = event.data.object?["friendly_name"]?.stringValue ?? ieee
                    let status = event.data.object?["status"]?.stringValue
                    Task { @MainActor in
                        switch status {
                        case "started":
                            InterviewLiveActivityCoordinator.shared.start(deviceName: name, ieeeAddress: ieee)
                        case "successful":
                            InterviewLiveActivityCoordinator.shared.finish(deviceName: name, ieeeAddress: ieee, success: true)
                        case "failed":
                            InterviewLiveActivityCoordinator.shared.finish(deviceName: name, ieeeAddress: ieee, success: false)
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
        case .deviceState(let name, let state):
            let previous = deviceStates[name] ?? [:]
            if !previous.isEmpty {
                let changes = LogMapperEngine.diff(previous, state)
                if !changes.isEmpty {
                    insertLogEntry(LogMapperEngine.stateChangeEntry(device: name, changes: changes))
                }
            }
            deviceStates[name] = state
            handleOTAState(for: name, state: state)
        case .deviceAvailability(let name, let available):
            deviceAvailability[name] = available
        case .deviceOTAUpdateResponse(let response):
            handleOTAResponse(response)
        case .deviceOTACheckResponse(let response):
            handleOTACheckResponse(response)
        case .permitJoinChanged(let enabled, let remaining):
            if let info = bridgeInfo {
                bridgeInfo = BridgeInfo(
                    version: info.version,
                    commit: info.commit,
                    coordinator: info.coordinator,
                    network: info.network,
                    logLevel: info.logLevel,
                    permitJoin: enabled,
                    permitJoinTimeout: remaining,
                    permitJoinEnd: remaining.map { Int(Date().timeIntervalSince1970 * 1000) + ($0 * 1000) },
                    restartRequired: info.restartRequired,
                    config: info.config
                )
            }

        case .bridgeResponse(let topic, let payload):
            if topic == Z2MTopics.bridgeResponseBackup, let handler = backupResponseHandler {
                backupResponseHandler = nil
                if payload.object?["status"]?.stringValue == "ok",
                   let zip = payload.object?["data"]?.object?["zip"]?.stringValue {
                    handler(zip, nil)
                } else {
                    let err = payload.object?["error"]?.stringValue ?? "Unknown error"
                    handler(nil, err)
                }
                break
            }
            // The options/info responses carry only `{restart_required}` (and
            // echo the request on error). The full config is delivered via the
            // separate `bridge/info` topic, so don't try to decode config here
            // — doing so would overwrite the real config with all-nils.
            guard payload.object?["status"]?.stringValue == "ok" else { break }
            if let restartRequired = payload.object?["data"]?.object?["restart_required"]?.boolValue,
               let info = bridgeInfo {
                bridgeInfo = info.copyUpdating(restartRequired: restartRequired)
            }

        case .bridgeHealth(let health):
            if let existing = bridgeHealth, health.process == nil {
                // Sparse response (e.g. bridge/response/health_check returns only {healthy:true})
                // Merge: preserve rich stats, update the healthy flag
                bridgeHealth = BridgeHealth(
                    healthy: health.healthy,
                    responseTime: existing.responseTime,
                    process: existing.process,
                    os: existing.os,
                    mqtt: existing.mqtt
                )
            } else {
                bridgeHealth = health
            }

        case .touchlinkScanResult(let devices):
            touchlinkDevices = devices
            touchlinkScanInProgress = false

        case .touchlinkIdentifyDone:
            touchlinkIdentifyInProgress = false

        case .touchlinkFactoryResetDone:
            touchlinkResetInProgress = false

        case .deviceRemoveResponse(let id, let ok, let errorMessage):
            pendingRemovals.remove(id)
            if ok {
                // Remove locally so the next bridge/devices snapshot doesn't
                // race with our List diff. Also clears keyed state so the
                // "Recently Added" backfill doesn't resurrect it.
                devices.removeAll { $0.friendlyName == id }
                deviceStates.removeValue(forKey: id)
                deviceAvailability.removeValue(forKey: id)
                otaUpdates.removeValue(forKey: id)
                deviceCheckResults.removeValue(forKey: id)
            } else {
                let message = errorMessage ?? "Failed to remove '\(id)'"
                let error = Z2MOperationError(
                    id: UUID(),
                    topic: Z2MTopics.bridgeResponseDeviceRemove,
                    message: message,
                    timestamp: .now
                )
                apply(.operationError(error))
            }

        case .deviceRenameResponse(let from, let to, let ok, let errorMessage):
            if let pendingIdx = pendingRenames.firstIndex(where: { $0.from == from && $0.to == to }) {
                pendingRenames.remove(at: pendingIdx)
            }
            if !ok {
                revertOptimisticRename(from: from, to: to)
                let message = errorMessage ?? "Failed to rename '\(from)' to '\(to)'"
                let error = Z2MOperationError(
                    id: UUID(),
                    topic: Z2MTopics.bridgeResponseDeviceRename,
                    message: message,
                    timestamp: .now
                )
                apply(.operationError(error))
            }

        case .operationError(let error):
            touchlinkScanInProgress = false
            touchlinkIdentifyInProgress = false
            touchlinkResetInProgress = false
            operationErrors.insert(error, at: 0)
            let entry = LogEntry(
                id: UUID(),
                timestamp: error.timestamp,
                level: .error,
                category: .general,
                namespace: "z2m:response",
                message: error.message,
                deviceName: nil
            )
            insertLogEntry(entry)
            enqueueNotification(InAppNotification(
                level: .error,
                title: "Operation Failed",
                subtitle: stripped(String(error.message.prefix(100))),
                logEntryID: entry.id,
                category: .operationFailed
            ))

        case .unknown:
            break
        }
    }

    // MARK: - Static helpers for bridge events

    static func logEntry(from event: BridgeDeviceEvent) -> LogEntry? {
        guard let data = event.data.object else { return nil }
        let deviceName = data["friendly_name"]?.stringValue
        let ieeeAddr = data["ieee_address"]?.stringValue
        let name = deviceName ?? ieeeAddr ?? "unknown"

        switch event.type {
        case "device_joined":
            return LogEntry(id: UUID(), timestamp: .now, level: .info, category: .deviceJoined, namespace: nil, message: "Device '\(name)' joined the network", deviceName: deviceName)
        case "device_announce":
            return LogEntry(id: UUID(), timestamp: .now, level: .info, category: .deviceAnnounce, namespace: nil, message: "Device '\(name)' announced", deviceName: deviceName)
        case "device_interview":
            let status = data["status"]?.stringValue ?? "unknown"
            let level: LogLevel = status == "failed" ? .error : .info
            return LogEntry(id: UUID(), timestamp: .now, level: level, category: .interview, namespace: nil, message: "Interview of '\(name)' \(status)", deviceName: deviceName)
        case "device_leave":
            return LogEntry(id: UUID(), timestamp: .now, level: .warning, category: .deviceLeave, namespace: nil, message: "Device '\(name)' left the network", deviceName: deviceName)
        default:
            return nil
        }
    }

    static func notification(from event: BridgeDeviceEvent, entry: LogEntry) -> InAppNotification? {
        switch event.type {
        case "device_leave":
            return InAppNotification(level: .warning, title: "Device Left Network", subtitle: entry.deviceName, logEntryID: entry.id, deviceName: entry.deviceName, category: .deviceLeft)
        case "device_interview":
            let status = event.data.object?["status"]?.stringValue ?? "unknown"
            switch status {
            case "started":
                return InAppNotification(level: .info, title: "Interviewing Device", subtitle: entry.deviceName, logEntryID: entry.id, deviceName: entry.deviceName, category: .interviewStarted)
            case "successful":
                return InAppNotification(level: .info, title: "Interview Successful", subtitle: entry.deviceName, logEntryID: entry.id, deviceName: entry.deviceName, category: .interviewSuccessful)
            case "failed":
                return InAppNotification(level: .error, title: "Interview Failed", subtitle: entry.deviceName, logEntryID: entry.id, deviceName: entry.deviceName, category: .interviewFailed)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
