import Foundation

extension AppStore {
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

    func notification(
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

    /// Z2M log messages sometimes embed their namespace at the start
    /// ("z2m:controller Something failed"). Strip it so notifications show
    /// only the human-readable part.
    func stripped(_ text: String) -> String {
        guard text.hasPrefix("z2m:") else { return text }
        if let spaceRange = text.range(of: " ") {
            return String(text[spaceRange.upperBound...])
        }
        return text
    }
}
