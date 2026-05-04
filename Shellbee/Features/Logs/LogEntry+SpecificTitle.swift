import Foundation

extension LogEntry {
    /// A title that says *what happened*, not the category. Generic "State
    /// Change" headers are useless when every other row in the log is a
    /// state change — the detail view should immediately tell the user
    /// "Humidity changed" / "Came online" / "Interview failed" so the
    /// reason for tapping into the row is the first thing they read.
    var specificTitle: String {
        if LogRowIconography.isLinkQualityOnly(self) {
            return "Link quality drifted"
        }
        if LogRowIconography.isBatteryOnly(self) {
            return "Battery report"
        }

        switch category {
        case .stateChange:
            return stateChangeTitle
        case .deviceJoined:
            return "Device joined"
        case .deviceAnnounce:
            return "Device announced"
        case .deviceLeave:
            return "Device left"
        case .interview:
            return interviewTitle
        case .general:
            return generalTitle
        }
    }

    private var stateChangeTitle: String {
        let metadata: Set<String> = ["linkquality", "last_seen"]
        let meaningful = (context?.stateChanges ?? []).filter { !metadata.contains($0.property) }
        if meaningful.count == 1, let only = meaningful.first {
            return "\(only.displayLabel) changed"
        }
        if meaningful.isEmpty { return "State change" }
        return "Multiple changes"
    }

    private var interviewTitle: String {
        let lower = message.lowercased()
        if lower.contains("successful") { return "Interview successful" }
        if lower.contains("failed") { return "Interview failed" }
        if lower.contains("started") { return "Interview started" }
        return "Interview"
    }

    private var generalTitle: String {
        switch level {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
}
