import SwiftUI

/// What the Activity accessory shows on its trailing edge: the new value of
/// a state change ("147 → 150"), or how long ago anything else happened.
struct ActivityAccessoryChange: Equatable {
    /// Z2M property key, e.g. "linkquality"; picks the glyph.
    let property: String
    /// Human label, e.g. "Link Quality"; read by VoiceOver.
    let label: String
    let from: String?
    let to: String
    let toValue: JSONValue

    private static let metadata: Set<String> = ["linkquality", "last_seen"]

    init?(entry: LogEntry) {
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges, !changes.isEmpty else { return nil }
        let meaningful = changes.filter { !Self.metadata.contains($0.property) }
        let candidates = meaningful.isEmpty ? changes : meaningful
        guard let primary = candidates.first(where: { $0.displayFrom != nil }) ?? candidates.first else { return nil }
        property = primary.property
        label = primary.displayLabel
        from = primary.displayFrom
        to = primary.displayTo
        toValue = primary.to
    }
}

struct ActivityAccessoryTrailing: View {
    let entry: LogEntry
    let isInline: Bool

    var body: some View {
        if let change = ActivityAccessoryChange(entry: entry) {
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
            .id("\(entry.summaryTitle)|\(change.label)")
            .monospacedDigit()
            .lineLimit(1)
            .animation(.smooth, value: change.to)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(change))
        } else if !isInline {
            ActivityRelativeTime(date: entry.timestamp)
        }
    }

    private func accessibilityText(_ change: ActivityAccessoryChange) -> String {
        if let from = change.from {
            return "\(change.label) changed from \(from) to \(change.to)"
        }
        return "\(change.label) \(change.to)"
    }
}
