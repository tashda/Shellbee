import SwiftUI

struct DeviceCardLastSeen: View {
    let lastSeen: Date?

    var body: some View {
        if let lastSeen {
            Text(compactRelativeString(for: lastSeen))
                .font(.system(size: DesignTokens.Size.lastSeenValueFont, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
            .monospacedDigit()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last seen \(accessibilityFormatter.localizedString(for: lastSeen, relativeTo: .now))")
        }
    }

    private var accessibilityFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    private func compactRelativeString(for date: Date) -> String {
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)

        if seconds < 3600 {
            let minutes = max(seconds / 60, 1)
            return "\(minutes)m ago"
        }

        if seconds < 86_400 {
            let hours = max(seconds / 3600, 1)
            return "\(hours)h ago"
        }

        let days = max(seconds / 86_400, 1)
        return "\(days)d ago"
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.md) {
        DeviceCardLastSeen(lastSeen: Date().addingTimeInterval(-300))
        DeviceCardLastSeen(lastSeen: nil)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
