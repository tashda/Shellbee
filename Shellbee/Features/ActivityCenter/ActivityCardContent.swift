import Foundation

/// The words on an Activity card, laid out like a notification: who the
/// event is about on top, what happened underneath.
struct ActivityCardContent: Equatable {
    let title: String
    let message: String
    let detail: String?

    init(title: String, message: String, detail: String? = nil) {
        self.title = title
        self.message = message
        self.detail = detail
    }

    init(entry: LogEntry, subject: ActivityStack.Subject, bridgeName: String) {
        let message: String
        let detail: String?
        switch subject {
        case .named(let name):
            title = name
            (message, detail) = Self.event(for: entry, subjectName: name)
        case .bridge:
            title = bridgeName
            message = entry.summaryTitle
            detail = Self.nonEmpty(entry.summarySubtitle, excluding: [bridgeName, entry.summaryTitle])
        }
        // A headline like "Error" or a log namespace says nothing; lead
        // with the actual message instead.
        if let detail, Self.isGeneric(message, for: entry) {
            self.message = detail
            self.detail = nil
        } else {
            self.message = message
            self.detail = detail
        }
    }

    private static func isGeneric(_ text: String, for entry: LogEntry) -> Bool {
        text == entry.namespace || LogLevel.allCases.contains { $0.label == text }
    }

    private static func event(for entry: LogEntry, subjectName: String) -> (String, String?) {
        if let activityTitle = entry.activityTitle {
            return (activityTitle, nonEmpty(entry.activitySubtitle, excluding: [subjectName]))
        }
        if let display = entry.bridgeTopicDisplay {
            return (display.title, nonEmpty(display.subtitle, excluding: [subjectName]))
        }
        if let changes = stateChangeText(entry) {
            return (changes, nil)
        }
        if entry.summaryTitle != subjectName {
            return (entry.summaryTitle, nonEmpty(entry.summarySubtitle, excluding: [subjectName]))
        }
        return (entry.summarySubtitle, nil)
    }

    /// "Colour set to Pink", "Turned on · Brightness: 60% → 80%", with
    /// "+N" when more changed. Same wording as the tab bar accessory.
    private static func stateChangeText(_ entry: LogEntry) -> String? {
        let wordings = entry.activityChangeWordings
        guard !wordings.isEmpty else { return nil }
        var parts = wordings.prefix(2).map(\.sentence)
        if wordings.count > 2 { parts.append("+\(wordings.count - 2)") }
        return parts.joined(separator: " · ")
    }

    private static func nonEmpty(_ text: String?, excluding: [String]) -> String? {
        guard let text, !text.isEmpty, !excluding.contains(text) else { return nil }
        return text
    }
}
