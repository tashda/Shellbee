import Foundation

extension AppStore {
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
        // Notifications are Activity records now, not a second transient UI
        // queue. Preferences decide whether an event is highlighted in
        // Notifications Only; they never discard the underlying Activity.
        let shouldHighlight = notificationFilter?(notification) ?? true

        var markedExistingEntry = false
        for id in notification.logEntryIDs {
            guard let index = logEntries.firstIndex(where: { $0.id == id }) else { continue }
            if shouldHighlight {
                logEntries[index].isActivityAttention = true
            }
            logEntries[index].activityTitle = notification.title
            logEntries[index].activitySubtitle = notification.subtitle
            markedExistingEntry = true
        }

        guard !markedExistingEntry else { return }

        let message = [notification.title, notification.subtitle]
            .compactMap { $0 }
            .joined(separator: " — ")
        insertLogEntry(LogEntry(
            id: UUID(),
            timestamp: .now,
            level: notification.level,
            category: .general,
            namespace: nil,
            message: message,
            deviceName: notification.deviceName,
            isActivityAttention: shouldHighlight,
            activityTitle: notification.title,
            activitySubtitle: notification.subtitle
        ))
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
