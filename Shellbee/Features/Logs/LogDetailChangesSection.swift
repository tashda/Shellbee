import SwiftUI

struct LogDetailChangesSection: View {
    let changes: [LogContext.StateChange]

    var body: some View {
        Section {
            ForEach(changes) { change in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(change.displayLabel)
                        .font(.subheadline)
                    Spacer()
                    if let from = change.displayFrom {
                        Text(from)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(change.displayTo)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(color(for: change))
                }
            }
        }
    }

    private func color(for change: LogContext.StateChange) -> Color {
        switch change.to {
        case .string(let s) where s == "ON": return .green
        case .string(let s) where s == "OFF": return .red
        case .bool(true): return .green
        case .bool(false): return .red
        default: return .primary
        }
    }
}

#Preview {
    let changes = [
        LogContext.StateChange(id: UUID(), property: "state", from: .string("OFF"), to: .string("ON"),
                               displayLabel: "State", displayFrom: "OFF", displayTo: "ON"),
        LogContext.StateChange(id: UUID(), property: "brightness", from: .int(128), to: .int(200),
                               displayLabel: "Brightness", displayFrom: "50%", displayTo: "78%"),
        LogContext.StateChange(id: UUID(), property: "linkquality", from: .int(98), to: .int(61),
                               displayLabel: "Link Quality", displayFrom: "98", displayTo: "61"),
    ]
    List { LogDetailChangesSection(changes: changes) }
}
