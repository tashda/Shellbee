import SwiftUI

/// The leading makers on Home, with the complete ranking available in place.
struct HomeVendorsCard: View {
    let devices: [Device]
    let onTap: () -> Void
    @State private var isExpanded = false

    private static let visibleCount = 5

    private var makers: [HomeStatsCount] {
        HomeStatsSnapshot.vendorCounts(for: devices)
    }

    var body: some View {
        let makers = makers
        ExpandableCardSurface(
            isExpanded: $isExpanded,
            hasMore: makers.count > Self.visibleCount,
            itemName: "vendors"
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ExpandableCardHeader(
                        isExpanded: $isExpanded,
                        hasMore: makers.count > Self.visibleCount,
                        itemName: "vendors"
                    ) {
                        CardHeader(
                            assetImage: "shellbee.vendors",
                            title: "Vendors",
                            value: makers.isEmpty ? nil : "\(makers.count) maker\(makers.count == 1 ? "" : "s")"
                        )
                    }
                    CardAccessoryButton(
                        systemImage: "arrow.up.right",
                        accessibilityLabel: "Open Device Statistics",
                        action: onTap
                    )
                }

                ExpandableCardRows(
                    isExpanded: $isExpanded,
                    items: makers,
                    previewCount: Self.visibleCount,
                    rowHeight: DesignTokens.Size.dashboardCompactRow,
                    spacing: DesignTokens.Spacing.xs
                ) { item, rank in
                    RankedBarRow(
                        title: item.title,
                        count: item.count,
                        rank: rank,
                        peak: makers.first?.count ?? 1
                    )
                }
            }
        }
    }
}

#Preview {
    HomeVendorsCard(devices: [], onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
