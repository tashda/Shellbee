import SwiftUI

/// What the Activity accessory shows on its trailing edge: the new value of
/// a state change ("147 → 150"), or how long ago anything else happened.
struct ActivityAccessoryChange: Equatable {
    /// Human label, e.g. "Link Quality"; read by VoiceOver.
    let label: String
    let from: String?
    let to: String

    init(label: String, from: String?, to: String) {
        self.label = label
        self.from = from
        self.to = to
    }

    init?(entry: LogEntry) {
        // The same change the instrument draws, so value and mark agree.
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges,
              let primary = ActivityInstrumentResolver.headline(of: changes) else { return nil }
        label = primary.displayLabel
        from = primary.displayFrom
        to = primary.displayTo
    }
}

struct ActivityAccessoryTrailing: View {
    let change: ActivityAccessoryChange?
    let timestamp: Date
    /// Who reported the change; digits roll only within one identity.
    let identity: String
    let isInline: Bool

    var body: some View {
        if let change {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                if !isInline, let from = change.from, from != change.to {
                    Text(from)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(change.to)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }
            // Digits roll only while the same device reports the same
            // property; a different device's value replaces it instead of
            // pretending one number changed.
            .id("\(identity)|\(change.label)")
            .monospacedDigit()
            .lineLimit(1)
            .animation(.smooth, value: change.to)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(change))
        } else if !isInline {
            ActivityRelativeTime(date: timestamp)
        }
    }

    private func accessibilityText(_ change: ActivityAccessoryChange) -> String {
        if let from = change.from {
            return "\(change.label) changed from \(from) to \(change.to)"
        }
        return "\(change.label) \(change.to)"
    }
}
