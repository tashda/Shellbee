import SwiftUI

/// One line in Home's "Needs attention" section: something that is wrong,
/// or waiting, and that you can act on from here.
///
/// The section exists only while this list is non-empty, so the shape of
/// Home answers "is anything wrong" before a single figure is read. Facts
/// with nothing to do about them — how many routers, the average link
/// quality, the channel — are not attention items and live on the screens
/// that own them.
struct HomeAttentionItem: Identifiable {
    enum Action {
        /// Open the Devices tab with this filter applied.
        case devices(DeviceQuickFilter)
        /// Restart this bridge, via Home's confirmation alert.
        case restart(UUID)
        /// Open the Zigbee2MQTT release notes.
        case release(URL)
    }

    let id: String
    let title: String
    let value: String
    let symbol: String
    /// Set only when the value needs attention; otherwise the row stays in
    /// the label colours.
    let tint: Color
    /// Set when the row is about one bridge rather than the network as a
    /// whole. The row then carries that bridge's colour on its leading
    /// edge, the way Devices, Groups and Logs already attribute rows —
    /// which says which bridge without spending the title on its name.
    var bridgeID: UUID? = nil
    let action: Action

    /// Builds the list, most severe first.
    ///
    /// - Parameters:
    ///   - snapshot: merged across every connected bridge, because a device
    ///     that stopped answering is one whichever bridge owns it.
    ///   - bridges: per-bridge entries, for the things that are genuinely
    ///     per-bridge (a pending restart, an available Z2M release).
    ///   - latestVersion: the tag `Z2MReleaseService` resolved, if any.
    static func items(
        snapshot: HomeSnapshot,
        bridges: [HomeBridgeCardEntry],
        latestVersion: String?
    ) -> [HomeAttentionItem] {
        var items: [HomeAttentionItem] = []

        if snapshot.offlineDevices > 0 {
            items.append(HomeAttentionItem(
                id: "offline",
                title: "Offline",
                value: deviceCount(snapshot.offlineDevices),
                symbol: "antenna.radiowaves.left.and.right.slash",
                tint: .red,
                action: .devices(.offline)
            ))
        }

        if snapshot.lowBatteryDevices > 0 {
            items.append(HomeAttentionItem(
                id: "battery",
                title: "Low battery",
                value: deviceCount(snapshot.lowBatteryDevices),
                symbol: "battery.25",
                tint: .red,
                action: .devices(.batteryLow)
            ))
        }

        for bridge in bridges where bridge.restartRequired {
            items.append(HomeAttentionItem(
                id: "restart-\(bridge.id)",
                title: "Restart required",
                value: "To apply configuration",
                symbol: "arrow.triangle.2.circlepath.circle.fill",
                tint: .orange,
                bridgeID: bridge.id,
                action: .restart(bridge.id)
            ))
        }

        if snapshot.weakSignalDevices > 0 {
            items.append(HomeAttentionItem(
                id: "signal",
                title: "Weak signal",
                value: deviceCount(snapshot.weakSignalDevices),
                symbol: "cellularbars",
                tint: .orange,
                action: .devices(.weakSignal)
            ))
        }

        if snapshot.devicesWithUpdates > 0 {
            items.append(HomeAttentionItem(
                id: "updates",
                title: "Firmware updates",
                value: "\(snapshot.devicesWithUpdates) ready",
                symbol: "arrow.down.circle.fill",
                tint: .blue,
                action: .devices(.updatesAvailable)
            ))
        }

        for bridge in bridges {
            guard let url = releaseURL(for: bridge, latestVersion: latestVersion),
                  let latest = latestVersion else { continue }
            items.append(HomeAttentionItem(
                id: "z2m-\(bridge.id)",
                title: "Zigbee2MQTT",
                value: "\(normalize(latest)) available",
                symbol: "arrow.down.circle.fill",
                tint: .blue,
                bridgeID: bridge.id,
                action: .release(url)
            ))
        }

        return items
    }

    private static func deviceCount(_ n: Int) -> String {
        "\(n) device\(n == 1 ? "" : "s")"
    }

    /// GitHub tags the releases both ways over time ("2.9.3", "v2.9.3").
    static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func releaseURL(for bridge: HomeBridgeCardEntry, latestVersion: String?) -> URL? {
        guard let latestVersion,
              let latest = Z2MVersion.parse(normalize(latestVersion)),
              let current = bridge.version.flatMap({ Z2MVersion.parse(normalize($0)) }),
              latest > current
        else { return nil }
        return URL(string: "https://github.com/Koenkk/zigbee2mqtt/releases/tag/\(latestVersion)")
    }
}

/// A Needs attention line: symbol, what it is, what's wrong with it.
struct HomeAttentionRow: View {
    let item: HomeAttentionItem

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: item.symbol)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.tint)
                .frame(width: DesignTokens.Size.summaryRowTrailingIcon)

            Text(item.title)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: DesignTokens.Spacing.sm)

            Text(item.value)
                .foregroundStyle(item.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        Section("Needs attention") {
            ForEach(HomeAttentionItem.items(
                snapshot: .preview,
                bridges: [.preview(name: "Home Bridge")],
                latestVersion: nil
            )) { item in
                HomeAttentionRow(item: item)
            }
        }
    }
}
