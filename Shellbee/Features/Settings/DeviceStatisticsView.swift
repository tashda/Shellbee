import Charts
import SwiftUI

struct DeviceStatisticsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    @State private var selectedBridgeID: UUID?

    init(bridgeID: UUID, defaultsToAllBridges: Bool = false) {
        self.bridgeID = bridgeID
        _selectedBridgeID = State(initialValue: defaultsToAllBridges ? nil : bridgeID)
    }

    private var bridges: [BridgeSession] {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        return connected.isEmpty ? environment.registry.orderedSessions : connected
    }

    private var stats: DeviceStatisticsSnapshot {
        let sources: [BridgeSession]
        if let selectedBridgeID {
            sources = environment.registry.session(for: selectedBridgeID).map { [$0] } ?? []
        } else {
            sources = bridges
        }
        let snapshots = sources.map { session in
            DeviceStatisticsSnapshot(
                devices: session.store.devices,
                availability: session.store.deviceAvailability,
                states: session.store.deviceStates
            )
        }
        return DeviceStatisticsSnapshot(merging: snapshots)
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
                    StatisticsRankingCard(
                        title: "Vendors",
                        systemImage: "",
                        assetImage: "shellbee.vendors",
                        items: stats.vendors,
                        distinctCount: stats.distinctVendors,
                        noun: "makers"
                    )
                    StatisticsRankingCard(
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
        .toolbar {
            if bridges.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            selectedBridgeID = nil
                        } label: {
                            if selectedBridgeID == nil { Label("All", systemImage: "checkmark") }
                            else { Text("All") }
                        }
                        ForEach(bridges, id: \.bridgeID) { bridge in
                            Button {
                                selectedBridgeID = bridge.bridgeID
                            } label: {
                                if selectedBridgeID == bridge.bridgeID {
                                    Label(bridgeName(bridge), systemImage: "checkmark")
                                } else {
                                    Text(bridgeName(bridge))
                                }
                            }
                        }
                    } label: {
                        Label(selectionTitle, systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .accessibilityLabel("Statistics for \(selectionTitle)")
                }
            }
        }
    }

    private var selectionTitle: String {
        guard let selectedBridgeID,
              let bridge = bridges.first(where: { $0.bridgeID == selectedBridgeID }) else {
            return "All"
        }
        return bridgeName(bridge)
    }

    private func bridgeName(_ bridge: BridgeSession) -> String {
        guard bridges.filter({ $0.displayName == bridge.displayName }).count > 1 else {
            return bridge.displayName
        }
        return "\(bridge.displayName) · \(bridge.config.port)"
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
