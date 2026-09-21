import SwiftUI

// Every Shellbee Live Activity follows one blueprint: a tinted glyph, a title
// and subtitle, and one large live value, on a glass gradient card. Each
// activity only declares a `LiveActivityLayout`; the shared views render it
// for the Lock Screen and every Dynamic Island presentation. These files are
// compiled into both the widget and the app, so the Developer gallery shows
// exactly what the system renders.

/// The single live value an activity is about.
enum LiveActivityValue {
    case countdown(ClosedRange<Date>)
    case text(String)
    case symbol(String)
}

/// Measurable progress, drawn as bars and rings. Timer-driven cases keep
/// moving on their own while the app is suspended.
enum LiveActivityGauge {
    case none
    case progress(Double)
    /// Drains from full to empty across the range.
    case countdown(ClosedRange<Date>)
    /// Fills from empty to full across the range, e.g. towards an estimated
    /// finish. Start the range in the past to begin part-way full.
    case filling(ClosedRange<Date>)

    var timer: (range: ClosedRange<Date>, countsDown: Bool)? {
        switch self {
        case .countdown(let range): return (range, true)
        case .filling(let range): return (range, false)
        case .none, .progress: return nil
        }
    }
}

/// One entry in a multi-item activity, such as a device in an update queue.
struct LiveActivityRow: Identifiable {
    let name: String
    /// Nil while the item is waiting and has no progress yet.
    let fraction: Double?
    let status: String
    var id: String { name }
}

enum LiveActivityPalette {
    static let pairing = Color(red: 0.35, green: 0.91, blue: 0.70)
    static let update = Color(red: 0.40, green: 0.70, blue: 1.00)
    static let scan = Color(red: 0.62, green: 0.56, blue: 1.00)
    static let identify = Color(red: 1.00, green: 0.82, blue: 0.30)
    static let working = Color.orange
    static let success = Color.green
    static let failure = Color.red
    static let neutral = Color.white
    // Card surface, after FotMob's graphite-to-indigo match card.
    static let cardGraphite = Color(red: 0.25, green: 0.25, blue: 0.29)
    static let cardIndigo = Color(red: 0.17, green: 0.17, blue: 0.33)
    static let cardNight = Color(red: 0.04, green: 0.04, blue: 0.08)
    /// Neutral surround for the Developer stage's miniature phone.
    static let stageBackdrop = Color(white: 0.11)
}

struct LiveActivityLayout {
    /// The activity's fixed identity icon, shown on the left of the compact
    /// island. It never changes with state: status belongs to `value`, on the
    /// right, so the two sides can never show the same icon.
    let symbol: String
    let tint: Color
    /// Optional context above the title, such as which bridge this is about.
    var eyebrow: String? = nil
    let title: String
    /// Tints the title for a moment worth celebrating or flagging.
    var titleTint: Color? = nil
    var subtitle: String? = nil
    let value: LiveActivityValue
    var gauge: LiveActivityGauge = .none
    /// Replaces `value` on the compact island's right for a brief moment,
    /// such as "+1" when a device finishes pairing.
    var compactValue: LiveActivityValue? = nil
    var compactTint: Color? = nil
    /// Work is in progress right now: the identity icon pulses.
    var isBusy = false
    /// A supporting number some styles show, such as devices joined.
    var metric: LiveActivityMetric? = nil
    /// Items the Queue style lists, most relevant first.
    var rows: [LiveActivityRow] = []
    var style: LiveActivityStyle = .classic

    /// When the activity's countdown ends, if it has one.
    var endsAt: Date? {
        gauge.timer?.range.upperBound
    }
}
