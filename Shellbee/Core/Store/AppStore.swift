import Foundation
import UIKit

@Observable
final class AppStore {
    var devices: [Device] = []
    var groups: [Group] = []
    var bridgeInfo: BridgeInfo?
    var bridgeHealth: BridgeHealth?
    var bridgeOnline = false
    var isConnected = false
    var deviceStates: [String: [String: JSONValue]] = [:]
    var deviceAvailability: [String: Bool] = [:]
    // First-seen timestamps keyed by ieeeAddress. Drives the "Recently Added"
    // section in the device list and is persisted across launches so the
    // 30-minute window keeps counting while the app is closed.
    var deviceFirstSeen: [String: Date] = [:]
    // Optimistic renames awaiting bridge confirmation. Used to roll back if z2m
    // returns status="error" for the rename request.
    private var pendingRenames: [(from: String, to: String)] = []
    // Friendly names of devices the user has asked to remove and we're awaiting
    // bridge/response/device/remove for. Drives the "Deleting" badge and
    // disables further swipe-deletes on the same row.
    var pendingRemovals: Set<String> = []
    private static let firstSeenStoreKey = "AppStore.deviceFirstSeen"
    var otaUpdates: [String: OTAUpdateStatus] = [:]
    var logEntries: [LogEntry] = []
    var rawLogEntries: [LogEntry] = []
    var operationErrors: [Z2MOperationError] = []
    var touchlinkDevices: [TouchlinkDevice] = []
    var touchlinkScanInProgress = false
    var touchlinkIdentifyInProgress = false
    var touchlinkResetInProgress = false
    var pendingNotifications: [InAppNotification] = []
    var fastTrackNotifications: [InAppNotification] = []
    // Bumped whenever a new (non-coalesced) normal notification is enqueued.
    // The overlay observes this to fire the arrival haptic exactly once per
    // new banner, independent of coalescing bumps.
    var notificationArrivalID: UUID = UUID()

    // Set by AppEnvironment to route OTA check/update responses into the
    // bulk queue so it can advance to the next device.
    var otaResponseForwarding: ((_ friendlyName: String, _ success: Bool, _ kind: OTABulkOperationQueue.Kind) -> Void)?

    // One-shot callback invoked when the next bridge/response/backup arrives.
    // BackupView sets this before sending the request and clears it on receipt.
    // Tuple: (zipBase64, errorMessage) — exactly one is non-nil.
    var backupResponseHandler: ((_ zipBase64: String?, _ error: String?) -> Void)?

    // Set by AppEnvironment to filter out notifications the user disabled
    // in Settings → App → Notifications. Returns true to allow.
    var notificationFilter: ((InAppNotification) -> Bool)?

    // Transient per-device check results rendered briefly in the row after
    // "Checking" resolves. Cleared automatically after a short interval.
    var deviceCheckResults: [String: DeviceCheckResult] = [:]

    enum DeviceCheckResult: Equatable {
        case noUpdate
        case updateFound
        case failed
    }

    static let logLimit = 1000
    static let coalesceWindow: TimeInterval = 1.5

    init() {
        if let raw = UserDefaults.standard.dictionary(forKey: Self.firstSeenStoreKey) as? [String: Double] {
            deviceFirstSeen = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    private func persistFirstSeen() {
        let raw = deviceFirstSeen.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: Self.firstSeenStoreKey)
    }

    private func recordFirstSeen(ieee: String, overwrite: Bool = false) {
        if !overwrite, deviceFirstSeen[ieee] != nil { return }
        deviceFirstSeen[ieee] = Date()
        persistFirstSeen()
    }

    private func removeFirstSeen(ieee: String) {
        guard deviceFirstSeen.removeValue(forKey: ieee) != nil else { return }
        persistFirstSeen()
    }

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

    func clearLogs() {
        logEntries = []
        rawLogEntries = []
    }

    func popNotification() -> InAppNotification? {
        guard !pendingNotifications.isEmpty else { return nil }
        return pendingNotifications.removeFirst()
    }

    func popFastTrackNotification() -> InAppNotification? {
        guard !fastTrackNotifications.isEmpty else { return nil }
        return fastTrackNotifications.removeFirst()
    }

    func enqueueOTABulkSummary(_ summary: OTABulkOperationQueue.CompletionSummary) {
        let noun = summary.kind == .check ? "Checked" : "Updated"
        let level: LogLevel = summary.failed > 0 ? .warning : .info
        let title: String
        if summary.wasCancelled {
            title = summary.kind == .check ? "Check Cancelled" : "Updates Cancelled"
        } else if summary.failed > 0 {
            title = "\(noun) \(summary.total) Devices"
        } else {
            title = "\(noun) \(summary.total) Devices"
        }
        var parts: [String] = []
        if summary.succeeded > 0 {
            parts.append("\(summary.succeeded) succeeded")
        }
        if summary.failed > 0 {
            parts.append("\(summary.failed) failed")
        }
        let subtitle = parts.isEmpty ? nil : parts.joined(separator: ", ")
        enqueueNotification(InAppNotification(
            level: level,
            title: title,
            subtitle: subtitle,
            category: .otaBulkSummary
        ))
    }

    func enqueueNotification(_ notification: InAppNotification) {
        // Fast-track bypasses the filter — these are transient confirmations
        // (e.g. "Copied to Clipboard") driven by the user's own action.
        if notification.priority == .fastTrack {
            fastTrackNotifications.append(notification)
            return
        }

        if let filter = notificationFilter, !filter(notification) { return }

        let now = Date()

        if let idx = pendingNotifications.lastIndex(where: { $0.coalesceKey == notification.coalesceKey }),
           now.timeIntervalSince(pendingNotifications[idx].lastUpdated) <= Self.coalesceWindow {
            pendingNotifications[idx].count += notification.count
            pendingNotifications[idx].logEntryIDs.append(contentsOf: notification.logEntryIDs)
            pendingNotifications[idx].occurrences.append(contentsOf: notification.occurrences)
            if let sub = notification.subtitle { pendingNotifications[idx].subtitle = sub }
            pendingNotifications[idx].lastUpdated = now
            return
        }

        pendingNotifications.append(notification)
        notificationArrivalID = UUID()
    }

    private func notification(
        for action: LogContext.LogAction, level: LogLevel,
        deviceName: String?, message: String, id: UUID
    ) -> InAppNotification? {
        let truncated = stripped(String(message.prefix(100)))
        switch action {
        case .bindSuccess:
            return InAppNotification(level: .info, title: "Bind Successful", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .bindSuccess)
        case .bindFailure:
            return InAppNotification(level: .error, title: "Bind Failed", subtitle: deviceName ?? truncated, logEntryID: id, deviceName: deviceName, category: .bindFailure)
        case .unbind:
            return InAppNotification(level: .info, title: "Unbound", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .unbind)
        case .groupAdd:
            return InAppNotification(level: .info, title: "Added to Group", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .groupAdd)
        case .groupRemove:
            return InAppNotification(level: .info, title: "Removed from Group", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .groupRemove)
        case .publishFailure(let command):
            let detail = command.isEmpty ? truncated : command
            return InAppNotification(level: .error, title: "Command Failed", subtitle: detail, logEntryID: id, deviceName: deviceName, category: .publishFailure)
        case .requestFailure:
            return InAppNotification(level: .error, title: "Request Failed", subtitle: truncated, logEntryID: id, deviceName: deviceName, category: .requestFailure)
        case .otaFinished:
            return InAppNotification(level: .info, title: "Update Installed", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .otaUpdateInstalled)
        case .reportingConfigure:
            return InAppNotification(level: .info, title: "Reporting Configured", subtitle: deviceName, logEntryID: id, deviceName: deviceName, category: .reportingConfigure)
        case .general where level == .error:
            return InAppNotification(level: .error, title: "Error", subtitle: truncated, logEntryID: id, deviceName: deviceName, category: .genericError)
        default:
            return nil
        }
    }

    // Z2M log messages sometimes embed their namespace at the start ("z2m:controller Something failed").
    // Strip it so notifications show only the human-readable part.
    private func stripped(_ text: String) -> String {
        guard text.hasPrefix("z2m:") else { return text }
        if let spaceRange = text.range(of: " ") {
            return String(text[spaceRange.upperBound...])
        }
        return text
    }

    private static func notification(from event: BridgeDeviceEvent, entry: LogEntry) -> InAppNotification? {
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

    private func insertLogEntry(_ entry: LogEntry) {
        logEntries.insert(entry, at: 0)
        if logEntries.count > Self.logLimit {
            logEntries = Array(logEntries.prefix(Self.logLimit))
        }
    }

    private func insertRawLogEntry(_ entry: LogEntry) {
        rawLogEntries.insert(entry, at: 0)
        if rawLogEntries.count > Self.logLimit {
            rawLogEntries = Array(rawLogEntries.prefix(Self.logLimit))
        }
    }

    private static func logEntry(from event: BridgeDeviceEvent) -> LogEntry? {
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

    func device(named friendlyName: String) -> Device? {
        devices.first { $0.friendlyName == friendlyName }
    }

    func state(for friendlyName: String) -> [String: JSONValue] {
        deviceStates[friendlyName] ?? [:]
    }

    func isAvailable(_ friendlyName: String) -> Bool {
        deviceAvailability[friendlyName] ?? false
    }

    // Apply a rename to local state immediately so the UI updates without
    // waiting for the bridge/devices snapshot (which can lag 3-10s after a
    // bridge/request/device/rename). Migrates availability and state keys so
    // the renamed device doesn't flicker through "offline".
    func optimisticRename(from: String, to: String) {
        guard from != to, !to.isEmpty else { return }
        guard let idx = devices.firstIndex(where: { $0.friendlyName == from }) else { return }
        var device = devices[idx]
        device.friendlyName = to
        devices[idx] = device

        if let availability = deviceAvailability.removeValue(forKey: from) {
            deviceAvailability[to] = availability
        }
        if let state = deviceStates.removeValue(forKey: from) {
            deviceStates[to] = state
        }
        pendingRenames.append((from: from, to: to))
    }

    private func revertOptimisticRename(from: String, to: String) {
        guard let idx = devices.firstIndex(where: { $0.friendlyName == to }) else { return }
        var device = devices[idx]
        device.friendlyName = from
        devices[idx] = device

        if let availability = deviceAvailability.removeValue(forKey: to) {
            deviceAvailability[from] = availability
        }
        if let state = deviceStates.removeValue(forKey: to) {
            deviceStates[from] = state
        }
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
        OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices)
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

    func reset() {
        devices = []
        groups = []
        bridgeInfo = nil
        bridgeHealth = nil
        bridgeOnline = false
        isConnected = false
        deviceStates = [:]
        deviceAvailability = [:]
        pendingRenames = []
        deviceFirstSeen = [:]
        UserDefaults.standard.removeObject(forKey: Self.firstSeenStoreKey)
        otaUpdates = [:]
        logEntries = []
        operationErrors = []
        pendingNotifications = []
        fastTrackNotifications = []
        deviceCheckResults = [:]
        pendingRemovals = []
        touchlinkDevices = []
        touchlinkScanInProgress = false
        touchlinkIdentifyInProgress = false
        touchlinkResetInProgress = false
        OTAUpdateLiveActivityCoordinator.shared.clearAll()
    }

    private var activeOTAUpdates: [OTAUpdateStatus] {
        otaUpdates.values.filter(\.isActive)
    }

    private func handleOTAState(for deviceName: String, state: [String: JSONValue]) {
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
                OTAUpdateLiveActivityCoordinator.shared.finish(for: deviceName, success: true)
                return
            }
        }

        OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices)
    }

    private func handleOTAResponse(_ response: DeviceOTAUpdateResponse) {
        if let deviceName = response.deviceName {
            otaResponseForwarding?(deviceName, response.isSuccess, .update)
        }
        guard !response.isSuccess else { return }
        guard let deviceName = response.deviceName else { return }

        otaUpdates.removeValue(forKey: deviceName)

        if activeOTAUpdates.isEmpty {
            OTAUpdateLiveActivityCoordinator.shared.finish(for: deviceName, success: false)
        } else {
            OTAUpdateLiveActivityCoordinator.shared.sync(with: activeOTAUpdates, devices: devices)
        }
    }

    private func handleOTACheckResponse(_ response: DeviceOTAUpdateResponse) {
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

    private func flashCheckResult(_ result: DeviceCheckResult, for deviceName: String) {
        deviceCheckResults[deviceName] = result
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                guard let self else { return }
                if self.deviceCheckResults[deviceName] == result {
                    self.deviceCheckResults.removeValue(forKey: deviceName)
                }
            }
        }
    }
}
