import Foundation

extension LogEntry {
    /// Noun-form label for the body section header in the detail view.
    /// Apple iOS section headers are noun phrases — "Signal", "Battery",
    /// "Humidity", "Interview" — never sentences. The body of the section
    /// supplies the verb (the diff rows show what actually changed). The
    /// timestamp lives in the nav-bar subtitle, so the body header doesn't
    /// need to repeat "what + when" — only "what".
    var bodyHeader: String {
        if LogRowIconography.isLinkQualityOnly(self) {
            return "Signal"
        }
        if LogRowIconography.isBatteryOnly(self) {
            return "Battery"
        }

        switch category {
        case .stateChange:
            return stateChangeBodyHeader
        case .deviceJoined:
            return "Joined"
        case .deviceAnnounce:
            return "Announcement"
        case .deviceLeave:
            return "Left"
        case .interview:
            return "Interview"
        case .availability:
            return "Availability"
        case .bridgeState:
            return "Bridge"
        case .bridgeActivity:
            return bridgeTopicDisplay?.title ?? "Bridge Activity"
        case .permitJoin:
            return "Pairing"
        case .general:
            return generalBodyHeader
        }
    }

    private var stateChangeBodyHeader: String {
        let metadata: Set<String> = ["linkquality", "last_seen"]
        let meaningful = (context?.stateChanges ?? []).filter { !metadata.contains($0.property) }
        // Single-property changes use the property label as the header
        // ("Humidity", "Brightness") so the section reads naturally with
        // the diff row underneath. Multi-property changes fall back to
        // a generic noun.
        if meaningful.count == 1, let only = meaningful.first {
            return only.displayLabel
        }
        if meaningful.isEmpty { return "State" }
        return "Changes"
    }

    private var generalBodyHeader: String {
        switch level {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Message"
        case .debug: return "Debug"
        }
    }
}
