import SwiftUI

/// One tappable search result per category. Each reuses the row the app
/// already shows in that category's own list, so a result looks the same
/// here as where it lives, and pushes the same detail view.
struct GlobalSearchResultRows: View {
    @Environment(AppEnvironment.self) private var environment
    let scope: GlobalSearchScope
    let results: GlobalSearchResults
    /// Rows to show; nil shows every result.
    var limit: Int? = nil

    var body: some View {
        switch scope {
        case .all:
            EmptyView()
        case .devices:
            ForEach(capped(results.devices)) { item in
                NavigationLink(value: DeviceRoute(bridgeID: item.bridgeID, device: item.device)) {
                    deviceRow(item)
                }
            }
        case .groups:
            ForEach(capped(results.groups)) { item in
                NavigationLink(value: GroupRoute(bridgeID: item.bridgeID, group: item.group)) {
                    GroupRowView(
                        group: item.group,
                        memberDevices: store(for: item.bridgeID)?.memberDevices(of: item.group) ?? []
                    )
                }
            }
        case .bridges:
            ForEach(capped(results.bridges)) { bridge in
                NavigationLink(value: BridgeSettingsRoute(bridgeID: bridge.id)) {
                    GlobalSearchBridgeRow(bridge: bridge)
                }
            }
        case .activity:
            ForEach(capped(results.activity)) { item in
                ActivitySubjectEvents.Row(
                    item: environment.activityEventItem(for: item),
                    bridgeID: item.bridgeID,
                    usesValueNavigation: true
                )
            }
        case .logs:
            ForEach(capped(results.logs)) { item in
                NavigationLink(value: LogsPaneRoute.bridge(LogRoute(bridgeID: item.bridgeID, entry: item.entry))) {
                    BridgeLogRowView(entry: item.entry)
                }
            }
        case .docs:
            ForEach(capped(results.docs)) { entry in
                NavigationLink(value: entry) {
                    DocEntryRow(entry: entry, showVendor: true)
                }
            }
        }
    }

    private func capped<T>(_ items: [T]) -> ArraySlice<T> {
        items.prefix(limit ?? items.count)
    }

    private func store(for bridgeID: UUID) -> AppStore? {
        environment.registry.session(for: bridgeID)?.store
    }

    @ViewBuilder
    private func deviceRow(_ item: BridgeBoundDevice) -> some View {
        let name = item.device.friendlyName
        let store = store(for: item.bridgeID)
        DeviceRowView(
            device: item.device,
            state: store?.state(for: name) ?? [:],
            isAvailable: store?.isAvailable(name) ?? false,
            otaStatus: store?.otaStatus(for: name),
            bridgeID: item.bridgeID,
            bridgeName: item.bridgeName
        )
    }
}

private struct GlobalSearchBridgeRow: View {
    let bridge: GlobalSearchBridge

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            GlobalSearchScope.bridges.symbol.image
                .font(.body.weight(.semibold))
                .foregroundStyle(BridgeColor.color(for: bridge.id))
                .frame(width: DesignTokens.Size.summaryRowSymbolFrame, height: DesignTokens.Size.summaryRowSymbolFrame)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(bridge.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var subtitle: String {
        let status = bridge.isConnected ? "Connected" : "Disconnected"
        guard let version = bridge.version else { return status }
        return "\(status) · v\(version)"
    }
}
