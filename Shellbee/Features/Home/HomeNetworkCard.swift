import SwiftUI

/// What the mesh is made of: how many devices, how many of them route, how
/// many sit at the edge. Three facts and nothing else — the offline count
/// is the Needs attention row above, groups have their own tab, and link
/// quality has its own card.
struct HomeNetworkCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(systemImage: "chart.bar.doc.horizontal", title: "Network") {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                StatStrip(items: [
                    StatStripItem(value: "\(snapshot.totalDevices)", caption: "Devices"),
                    StatStripItem(value: "\(snapshot.routerCount)", caption: "Routers"),
                    StatStripItem(value: "\(snapshot.endDeviceCount)", caption: "End devices"),
                ])
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeNetworkCard(snapshot: .preview, onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
