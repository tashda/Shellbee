import SwiftUI

/// What the Activity accessory shows on its trailing edge: the new value of
/// a state change ("147 → 150"), or how long ago anything else happened.
struct ActivityAccessoryChange: Equatable {
    let wording: ActivityChangeWording

    init(wording: ActivityChangeWording) {
        self.wording = wording
    }

    /// The same change the instrument draws, so value and mark agree.
    init?(entry: LogEntry) {
        guard let headline = entry.activityChangeWordings.first else { return nil }
        wording = headline
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
            if let value = isInline ? change.wording.compact : change.wording.to {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                    if !isInline, let from = change.wording.from {
                        Text(from)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }
                // Digits roll only while the same device reports the same
                // property; a different device's value replaces it instead of
                // pretending one number changed.
                .id("\(identity)|\(change.wording.label)")
                .monospacedDigit()
                .lineLimit(1)
                .animation(.smooth, value: value)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(change.wording))
            }
        } else if !isInline {
            ActivityRelativeTime(date: timestamp)
        }
    }

    private func accessibilityText(_ wording: ActivityChangeWording) -> String {
        wording.sentence
    }
}
