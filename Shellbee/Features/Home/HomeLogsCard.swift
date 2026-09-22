import SwiftUI

struct HomeLogsCard: View {
    let items: [ActivityEventItem]
    var showsExpandedDetails = false
    var bridgeName: String? = nil
    let onOpenItem: (ActivityEventItem) -> Void
    let onOpenAll: () -> Void

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    HomeCardTitle(symbol: .custom("activity"), title: cardTitle, tint: .blue)
                    Spacer()
                    Button("Show All", action: onOpenAll)
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }

                if items.isEmpty {
                    Text("No recent events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        Divider().padding(.top, DesignTokens.Spacing.xs)
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            Button { onOpenItem(item) } label: {
                                HomeLogRow(item: item, showsExpandedDetails: showsExpandedDetails)
                            }
                            .buttonStyle(HomeAlertRowButtonStyle())
                            if index < items.count - 1 {
                                Divider().padding(.leading, HomeLogRow.leadingInset)
                            }
                        }
                    }
                }
            }
        }
    }

    private var cardTitle: String {
        bridgeName.map { "Recent Events · \($0)" } ?? "Recent Events"
    }
}

/// A Recent Events row: the same event row the Activity feed uses, with
/// the raw log line underneath on wide layouts.
struct HomeLogRow: View {
    let item: ActivityEventItem
    var showsExpandedDetails = false

    static let badgeSize: CGFloat = 32
    static var leadingInset: CGFloat { badgeSize + DesignTokens.Spacing.md }

    var body: some View {
        ActivityEventRow(
            instrument: item.instrument,
            content: item.content,
            timestamp: item.timestamp,
            instrumentSize: Self.badgeSize
        ) {
            if showsExpandedDetails, let entry = item.entry {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    StatusChip(entry.category)
                    StatusChip(entry.level)
                }
                .padding(.top, DesignTokens.Spacing.xxs)
                Text(LogEntry.stripZ2MPrefix(entry.message))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
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
