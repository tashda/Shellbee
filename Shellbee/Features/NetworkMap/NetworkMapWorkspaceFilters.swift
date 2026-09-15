import SwiftUI

/// Network Map's sidebar filter section, matching the row-with-checkmark
/// convention `DeviceWorkspaceFilters`/`ActivityWorkspaceFilters` use rather
/// than a chip strip — chips sat directly under the nav bar where iOS's
/// chrome effects live, and ate into the map's own vertical space besides.
struct NetworkMapWorkspaceFilters: View {
    @Environment(AppEnvironment.self) private var environment
    @Binding var filters: Set<NetworkMapFilter>
    @Binding var selectedBridgeID: UUID?

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        Section("Network Map") {
            if !connectedSessions.isEmpty {
                Picker("Network", selection: $selectedBridgeID) {
                    ForEach(connectedSessions, id: \.bridgeID) { session in
                        Text(session.displayName)
                            .tag(UUID?.some(session.bridgeID))
                    }
                }
                .accessibilityLabel("Network Map Network")
            }
            ForEach(NetworkMapFilter.allCases) { filter in
                filterButton(filter)
            }
            if !filters.isEmpty {
                Button("Clear Filters", role: .destructive) { filters.removeAll() }
            }
        }
    }

    private func filterButton(_ filter: NetworkMapFilter) -> some View {
        let isSelected = filters.contains(filter)
        return Button {
            if isSelected { filters.remove(filter) } else { filters.insert(filter) }
        } label: {
            HStack {
                Label(filter.rawValue, systemImage: filter.systemImage)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Active filter" : "")
    }
}
