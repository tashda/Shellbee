import SwiftUI

/// The same bounded reveal used by Home's Vendors and Batteries cards.
struct StatisticsRankingCard: View {
    let title: String
    let systemImage: String
    let items: [DeviceStatisticsSnapshot.Count]
    let distinctCount: Int
    let noun: String
    @State private var isExpanded = false

    private static let visibleCount = 7

    var body: some View {
        ExpandableCardSurface(
            isExpanded: $isExpanded,
            hasMore: items.count > Self.visibleCount,
            itemName: noun
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ExpandableCardHeader(
                    isExpanded: $isExpanded,
                    hasMore: items.count > Self.visibleCount,
                    itemName: noun
                ) {
                    CardHeader(
                        systemImage: systemImage,
                        title: title,
                        value: "\(distinctCount) \(noun)"
                    )
                }
                ExpandableCardRows(
                    isExpanded: $isExpanded,
                    items: items,
                    previewCount: Self.visibleCount,
                    rowHeight: DesignTokens.Size.dashboardCompactRow,
                    spacing: DesignTokens.Spacing.xs
                ) { item, rank in
                    RankedBarRow(
                        title: item.title,
                        count: item.count,
                        rank: rank,
                        peak: items.first?.count ?? 1
                    )
                }
            }
        }
    }
}
