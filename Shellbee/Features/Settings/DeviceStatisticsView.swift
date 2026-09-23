import Charts
import SwiftUI

struct DeviceStatisticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var expandedRankings: Set<String> = []
    /// Statistics are per-bridge: each Z2M instance has its own device list,
    /// so aggregating across bridges would conflate two networks. The Server
    /// page links here from a specific bridge's detail.
    let bridgeID: UUID

    private var stats: DeviceStatisticsSnapshot {
        let store = environment.scope(for: bridgeID).store
        return DeviceStatisticsSnapshot(
            devices: store.devices,
            availability: store.deviceAvailability,
            states: store.deviceStates
        )
    }

    var body: some View {
        ScrollView {
            if stats.totalDevices == 0 {
                ContentUnavailableView(
                    "No Device Statistics",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Device statistics will appear after the bridge reports its devices.")
                )
                .padding(.top, DesignTokens.Spacing.xxl)
            } else {
                LazyVStack(spacing: DesignTokens.Spacing.lg) {
                    overviewCard
                    compositionCard
                    powerSourcesCard
                    rankingCard(
                        title: "Vendors",
                        assetImage: "shellbee.vendors",
                        items: stats.vendors,
                        distinctCount: stats.distinctVendors,
                        noun: "makers"
                    )
                    rankingCard(
                        title: "Models",
                        assetImage: "shellbee.models",
                        items: stats.models,
                        distinctCount: stats.distinctModels,
                        noun: "models"
                    )
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: DesignTokens.Size.readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Device Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(instrument: .init(kind: .network), title: "Network overview")

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text("\(stats.totalDevices)")
                    .font(DesignTokens.Typography.heroValue)
                    .monospacedDigit()
                Text(stats.totalDevices == 1 ? "device" : "devices")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            StatStrip(items: [
                StatStripItem(
                    value: "\(stats.onlineDevices)",
                    caption: "Online",
                    dotColor: stats.offlineDevices > 0 ? nil : .green
                ),
                StatStripItem(
                    value: "\(stats.offlineDevices)",
                    caption: "Offline",
                    valueColor: stats.offlineDevices > 0 ? .red : nil,
                    dotColor: stats.offlineDevices > 0 ? .red : nil
                ),
                StatStripItem(value: "\(stats.batteryDevices)", caption: "On battery"),
                StatStripItem(
                    value: stats.averageLinkQuality.map(String.init) ?? "—",
                    caption: "Average LQI"
                ),
            ])

        }
        .cardSurface()
    }

    private var compositionCard: some View {
        breakdownCard(
            title: "Device types",
            instrument: .init(kind: .network),
            items: stats.deviceTypes
        )
    }

    private var powerSourcesCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(instrument: .init(kind: .energy), title: "Power sources")
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                ForEach(stats.powerSources) { item in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ActivityInstrumentView(
                            instrument: powerInstrument(for: item.title),
                            size: DesignTokens.Size.heroSymbol
                        )
                        Text("\(item.count)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardSurface()
    }

    private func breakdownCard(
        title: String,
        instrument: ActivityInstrument,
        items: [DeviceStatisticsSnapshot.Count]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(instrument: instrument, title: title)

            HStack(spacing: DesignTokens.Spacing.xl) {
                ZStack {
                    Chart(Array(items.enumerated()), id: \.element.id) { index, item in
                        SectorMark(
                            angle: .value("Devices", item.count),
                            innerRadius: .ratio(DesignTokens.Ratio.statisticsDonutInnerRadius),
                            angularInset: DesignTokens.Spacing.xxs
                        )
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                        .foregroundStyle(chartColor(index: index, total: items.count))
                    }
                    .chartLegend(.hidden)

                    VStack(spacing: 0) {
                        Text("\(items.reduce(0) { $0 + $1.count })")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        Text("devices")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
                }
                .frame(width: DesignTokens.Size.statisticsDonut,
                       height: DesignTokens.Size.statisticsDonut)

                legend(items)
            }
        }
        .cardSurface()
    }

    private func rankingCard(
        title: String,
        assetImage: String,
        items: [DeviceStatisticsSnapshot.Count],
        distinctCount: Int,
        noun: String
    ) -> some View {
        let visibleLimit = 7
        let isExpanded = expandedRankings.contains(title)
        let visible = isExpanded ? items : Array(items.prefix(visibleLimit))
        let remainder = items.dropFirst(visibleLimit).reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(
                assetImage: assetImage,
                title: title,
                value: "\(distinctCount) \(noun)"
            )
            horizontalBarChart(visible, visibleLimit: visibleLimit)
                .overlay(alignment: .bottom) {
                    if !isExpanded && remainder > 0 { ExpandableCardFade() }
                }
            if remainder > 0 {
                ExpandableCardFooter(
                    isExpanded: Binding(
                        get: { expandedRankings.contains(title) },
                        set: { newValue in
                            if newValue { expandedRankings.insert(title) }
                            else { expandedRankings.remove(title) }
                        }
                    ),
                    remainingCount: remainder,
                    itemName: noun
                )
            }
        }
        .cardSurface()
    }

    private func horizontalBarChart(
        _ items: [DeviceStatisticsSnapshot.Count],
        visibleLimit: Int
    ) -> some View {
        Chart(Array(items.enumerated()), id: \.element.id) { index, item in
            BarMark(
                x: .value("Devices", item.count),
                y: .value("Name", item.title)
            )
            .foregroundStyle(chartColor(index: index, total: max(items.count, visibleLimit)))
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(item.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: max(
            DesignTokens.Size.statisticsMinimumBarChart,
            CGFloat(items.count) * DesignTokens.Size.statisticsBarRow
        ))
    }

    private func legend(_ items: [DeviceStatisticsSnapshot.Count]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Circle()
                        .fill(chartColor(index: index, total: items.count))
                        .frame(width: DesignTokens.Size.statusDot,
                               height: DesignTokens.Size.statusDot)
                    Text(item.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    Text("\(item.count)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chartColor(index: Int, total: Int) -> Color {
        if total <= 3 {
            let palette: [Color] = [.blue, .orange, .gray]
            return palette[min(index, palette.count - 1)]
        }
        let progress = total <= 1 ? 0 : Double(index) / Double(total - 1)
        return Color.accentColor.opacity(DesignTokens.Opacity.statisticsChartHigh
            - progress * DesignTokens.Opacity.statisticsChartRange)
    }

    private func powerInstrument(for title: String) -> ActivityInstrument {
        switch title {
        case "Mains": .init(kind: .energy)
        case "Battery": .init(kind: .battery, normalizedValue: 0.7)
        default: .init(kind: .unknown)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceStatisticsView(bridgeID: UUID()).environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
