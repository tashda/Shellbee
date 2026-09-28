import Foundation

/// How one state change reads everywhere in Activity: the sentence on a
/// card, the tab bar's minimized value, and its expanded from → to.
///
/// A value only earns space when it tells you something the instrument
/// can't. Colours, on/off states and button presses are already drawn by
/// their instrument, so they show no value when minimized; measurements
/// keep theirs, with a unit.
struct ActivityChangeWording: Equatable {
    /// The card message, e.g. "Colour set to Pink", "Turned on",
    /// "Humidity: 48% → 53%".
    let sentence: String
    /// The minimized tab bar value; nil leaves the name the full width.
    let compact: String?
    /// Expanded tab bar: "from → to", or just `to` when `from` is nil.
    let from: String?
    let to: String?
    /// VoiceOver label for the change, e.g. "Humidity".
    let label: String

    /// Anything longer than this in the minimized tab bar would cut off
    /// the device name, which always wins.
    static let compactLimit = 6

    init(change: LogContext.StateChange, state: [String: JSONValue]? = nil) {
        let label = change.displayLabel
        self.label = label
        let property = change.property.lowercased()
        let kind = ActivityInstrumentResolver.kind(forProperty: property)
        // At the precision shown, "0,35 → 0,35" didn't change: drop the arrow.
        let from = change.displayFrom == change.displayTo ? nil : change.displayFrom

        if kind == .colour {
            let (sentence, value) = Self.colour(change: change, property: property, state: state)
            (self.sentence, compact, self.from, to) = (sentence, nil, nil, value)
        } else if let word = Self.stateWord(property: property, value: change.to) {
            sentence = Self.stateSentence(property: property, label: label, word: word, value: change.to)
            (compact, self.from, to) = (nil, nil, word)
        } else if kind == .action {
            let action = Self.humanize(change.to.stringValue ?? change.displayTo)
            sentence = String(localized: "Pressed \(action)")
            (compact, self.from, to) = (nil, nil, action)
        } else {
            sentence = from.map { "\(label): \($0) → \(change.displayTo)" } ?? "\(label): \(change.displayTo)"
            self.from = from
            to = change.displayTo
            let isMeasurement = change.to.numberValue != nil
            compact = isMeasurement && change.displayTo.count <= Self.compactLimit ? change.displayTo : nil
        }
    }

    // MARK: - Colour

    private static func colour(
        change: LogContext.StateChange, property: String, state: [String: JSONValue]?
    ) -> (sentence: String, value: String?) {
        let mode = state?["color_mode"]?.stringValue
        if property.contains("temp") || mode == "color_temp" {
            let raw = state?["color_temp"]?.numberValue ?? change.to.numberValue
            guard let raw else { return (String(localized: "Colour temperature changed"), nil) }
            let kelvin = Int((raw > 1_000 ? raw : 1_000_000 / max(raw, 1)).rounded())
            return (String(localized: "Colour temperature \(kelvin) K"), "\(kelvin) K")
        }
        let color = state.flatMap(LightDisplayColor.resolve(state:))
            ?? LightDisplayColor.color(property: property, value: change.to)
        guard let color else { return (String(localized: "Colour changed"), nil) }
        let name = LightDisplayColor.name(for: color)
        return (String(localized: "Colour set to \(name)"), name)
    }

    // MARK: - States

    /// A plain word for a two-state property, or nil when it isn't one.
    private static func stateWord(property: String, value: JSONValue) -> String? {
        guard let on = boolean(value) else { return nil }
        switch property {
        case "state": return on ? String(localized: "On") : String(localized: "Off")
        // Z2M reports contact: true for closed.
        case "contact": return on ? String(localized: "Closed") : String(localized: "Open")
        case "lock", "child_lock": return on ? String(localized: "Locked") : String(localized: "Unlocked")
        default:
            switch ActivityInstrumentResolver.kind(forProperty: property) {
            case .presence, .safety: return on ? String(localized: "Detected") : String(localized: "Clear")
            default: return value.boolValue.map { $0 ? String(localized: "Yes") : String(localized: "No") }
            }
        }
    }

    private static func stateSentence(property: String, label: String, word: String, value: JSONValue) -> String {
        let on = boolean(value) ?? false
        switch property {
        case "state": return on ? String(localized: "Turned on") : String(localized: "Turned off")
        case "contact": return on ? String(localized: "Closed") : String(localized: "Opened")
        case "lock", "child_lock": return on ? String(localized: "Locked") : String(localized: "Unlocked")
        default:
            switch ActivityInstrumentResolver.kind(forProperty: property) {
            case .presence, .safety: return on ? String(localized: "\(label) detected") : String(localized: "\(label) cleared")
            default: return "\(label): \(word)"
            }
        }
    }

    private static func boolean(_ value: JSONValue) -> Bool? {
        if let bool = value.boolValue { return bool }
        switch value.stringValue?.lowercased() {
        case "on", "lock", "locked", "true", "detected", "occupied": return true
        case "off", "unlock", "unlocked", "false", "clear", "unoccupied": return false
        default: return nil
        }
    }

    /// "brightness_move_up" → "Brightness Move Up".
    private static func humanize(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

extension LogEntry {
    /// The changes worth wording, headline first: link quality and last-seen
    /// only when nothing else changed, and one line per colour however many
    /// coordinates the device reported.
    var activityChangeWordings: [ActivityChangeWording] {
        guard category == .stateChange, let changes = context?.stateChanges, !changes.isEmpty else { return [] }
        let metadata: Set<String> = ["linkquality", "last_seen"]
        let meaningful = changes.filter { !metadata.contains($0.property) }
        let candidates = meaningful.isEmpty ? changes : meaningful
        let headline = ActivityInstrumentResolver.headline(of: candidates)
        let ordered = headline.map { first in [first] + candidates.filter { $0.id != first.id } } ?? candidates

        var seen = Set<String>()
        return ordered
            .map { ActivityChangeWording(change: $0, state: context?.payload) }
            .filter { seen.insert($0.sentence).inserted }
    }
}
