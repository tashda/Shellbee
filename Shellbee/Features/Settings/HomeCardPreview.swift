import SwiftUI

/// What every Home card preview reads, built once per Settings render.
struct HomeCardPreviewData {
    let snapshot: HomeSnapshot
    let readings: [HomeDeviceReading]
    let bridgeEntries: [HomeBridgeCardEntry]
    let devices: [Device]
    let recentEvents: [ActivityEventItem]

    private static let activityRows = 3

    @MainActor
    init(environment: AppEnvironment) {
        let bridgeID = environment.registry.primaryBridgeID ?? environment.registry.orderedSessions.first?.bridgeID
        snapshot = environment.homeSnapshot(selectedBridgeID: bridgeID)
        readings = environment.homeDeviceReadings(selectedBridgeID: bridgeID)
        bridgeEntries = environment.homeBridgeCardEntries(selectedBridgeID: bridgeID)
        devices = environment.allDevices.map(\.device)
        recentEvents = environment.allLogEntries.prefix(Self.activityRows).map(environment.activityEventItem(for:))
    }
}

/// A Home card drawn with the user's own data, for Settings › Home Screen.
/// Actions are no-ops; the preview isn't interactive.
struct HomeCardPreview: View {
    let kind: HomeCardKind
    let data: HomeCardPreviewData

    private static let scale = DesignTokens.Ratio.homeCardPreview

    var body: some View {
        ScaledPreview(scale: Self.scale) {
            card
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card * Self.scale, style: .continuous)
                .strokeBorder(.separator)
        }
    }

    @ViewBuilder
    private var card: some View {
        let snapshot = data.snapshot
        switch kind {
        case .network:
            HomeNetworkCard(snapshot: snapshot, onTap: {}, onOpenStatistics: {})
        case .linkQuality:
            HomeLinkQualityCard(
                snapshot: snapshot,
                readings: data.readings,
                onTapWeak: {},
                onOpenPage: {}
            )
        case .batteries:
            HomeBatteriesCard(
                snapshot: snapshot,
                readings: data.readings,
                onSelect: { _ in },
                onOpenPage: {}
            )
        case .vendors:
            HomeVendorsCard(devices: data.devices)
        case .bridgeHealth:
            let entries = data.bridgeEntries
            if entries.count >= 2 {
                HomeBridgeHealthGroupCard(entries: entries) { _ in }
            } else if let entry = entries.first {
                HomeBridgeHealthCard(entry: entry) {}
            }
        case .activity:
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(data.recentEvents) { HomeActivityRow(item: $0) }
            }
            .cardSurface()
        }
    }
}
