import SwiftUI

/// What the mesh is made of: how many devices, how many of them route, how
/// many sit at the edge. Three facts and nothing else — the offline count
/// is the Needs attention row above, groups have their own tab, and link
/// quality has its own card. Tapping the card opens the Network Map; ↗
/// opens Device Statistics, the full page behind these figures.
struct HomeNetworkCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void
    let onOpenStatistics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                CardHeader(instrument: .init(kind: .network), title: "Network")
                CardAccessoryButton(
                    systemImage: "arrow.up.right",
                    accessibilityLabel: "Open Device Statistics",
                    action: onOpenStatistics
                )
            }

            StatStrip(items: [
                StatStripItem(value: "\(snapshot.totalDevices)", caption: "Devices"),
                StatStripItem(value: "\(snapshot.routerCount)", caption: "Routers"),
                StatStripItem(value: "\(snapshot.endDeviceCount)", caption: "End devices"),
            ])
        }
        .cardSurface()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityAction(named: "Open Network Map", onTap)
    }
}

#Preview {
    HomeNetworkCard(snapshot: .preview, onTap: {}, onOpenStatistics: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
