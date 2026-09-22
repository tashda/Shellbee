import Charts
import SwiftUI

struct DeviceStatisticsView: View {
    @Environment(AppEnvironment.self) private var environment
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
                        systemImage: "building.2",
                        items: stats.vendors,
                        distinctCount: stats.distinctVendors,
                        noun: "makers"
                    )
                    rankingCard(
                        title: "Models",
                        systemImage: "square.stack.3d.up",
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
            CardHeader(systemImage: "chart.bar.doc.horizontal", title: "Network overview")

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

            availabilityChart
        }
        .cardSurface()
    }

    private var availabilityChart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Availability")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(stats.supportedDevices) supported · \(stats.devicesReportingLinkQuality) with LQI")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
            }

            Chart(stats.availability) { item in
                BarMark(
                    x: .value("Devices", item.count),
                    stacking: .normalized
                )
                .foregroundStyle(availabilityColor(item.title))
                .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: DesignTokens.Size.statisticsAvailabilityChart)

            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(stats.availability) { item in
                    Label {
                        Text("\(item.title) \(item.count)")
                    } icon: {
                        Circle()
                            .fill(availabilityColor(item.title))
                            .frame(width: DesignTokens.Size.statusDotInline,
                                   height: DesignTokens.Size.statusDotInline)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var compositionCard: some View {
        breakdownCard(
            title: "Device types",
            systemImage: "point.3.connected.trianglepath.dotted",
            items: stats.deviceTypes,
            chartStyle: .donut
        )
    }

    private var powerSourcesCard: some View {
        breakdownCard(
            title: "Power sources",
            systemImage: "bolt.fill",
            items: stats.powerSources,
            chartStyle: .bars
        )
    }

    private enum BreakdownChartStyle { case donut, bars }

    private func breakdownCard(
        title: String,
        systemImage: String,
        items: [DeviceStatisticsSnapshot.Count],
        chartStyle: BreakdownChartStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(systemImage: systemImage, title: title)

            if chartStyle == .donut {
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
            } else {
                horizontalBarChart(items, visibleLimit: items.count)
            }
        }
        .cardSurface()
    }

    private func rankingCard(
        title: String,
        systemImage: String,
        items: [DeviceStatisticsSnapshot.Count],
        distinctCount: Int,
        noun: String
    ) -> some View {
        let visibleLimit = 7
        let visible = Array(items.prefix(visibleLimit))
        let remainder = items.dropFirst(visibleLimit).reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(
                systemImage: systemImage,
                title: title,
                value: "\(distinctCount) \(noun)"
            )
            horizontalBarChart(visible, visibleLimit: visibleLimit)
            if remainder > 0 {
                Text("\(remainder) more devices across \(items.count - visibleLimit) \(noun)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        let progress = total <= 1 ? 0 : Double(index) / Double(total - 1)
        return Color.accentColor.opacity(
            DesignTokens.Opacity.statisticsChartHigh
                - progress * DesignTokens.Opacity.statisticsChartRange
        )
    }

    private func availabilityColor(_ title: String) -> Color {
        switch title {
        case "Online": .green
        case "Offline": .red
        default: Color(.tertiaryLabel)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceStatisticsView(bridgeID: UUID()).environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
