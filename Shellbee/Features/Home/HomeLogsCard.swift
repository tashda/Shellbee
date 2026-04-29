import SwiftUI

struct HomeLogsCard: View {
    let entries: [LogEntry]
    let onOpenEntry: (LogEntry) -> Void
    let onOpenAll: () -> Void

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    HomeCardTitle(symbol: "list.bullet.rectangle.fill", title: "Recent Events", tint: .blue)
                    Spacer()
                    Button("Show All", action: onOpenAll)
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }

                if entries.isEmpty {
                    Text("No recent events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        Divider().padding(.top, DesignTokens.Spacing.xs)
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            Button { onOpenEntry(entry) } label: {
                                HomeLogRow(entry: entry)
                            }
                            .buttonStyle(HomeAlertRowButtonStyle())
                            if index < entries.count - 1 {
                                Divider().padding(.leading, HomeLogRow.leadingInset)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HomeLogRow: View {
    let entry: LogEntry

    static let badgeSize: CGFloat = 26
    static var leadingInset: CGFloat { badgeSize + DesignTokens.Spacing.md }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            badge
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(entry.summaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entry.summarySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var badge: some View {
        Circle()
            .fill(entry.level.color.opacity(DesignTokens.Opacity.onStateTint))
            .frame(width: Self.badgeSize, height: Self.badgeSize)
            .overlay {
                Image(systemName: entry.category.systemImage)
                    .font(DesignTokens.Typography.eyebrowLabelLarge)
                    .foregroundStyle(entry.level.color)
            }
    }
}

private struct HomeAlertRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}
