import SwiftUI

/// The Activity Center's raw log: zigbee2mqtt lines in minute cards, with
/// the same frame as the Activity feed. Tapping a line opens it in a sheet.
struct RawLogFeedView: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: BridgeLogViewModel
    @State private var presentedEntry: LogEntry?

    var body: some View {
        let blocks = RawLogBlock.blocks(from: mergedEntries())
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(blocks) { block in
                    Text(block.minute, format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Spacing.sm)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(block.lines.enumerated()), id: \.element.id) { index, item in
                        Button {
                            presentedEntry = item.entry
                        } label: {
                            RawLogRow(
                                entry: item.entry,
                                position: RawLogRow.Position(index: index, count: block.lines.count)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.ActivityFeed.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .overlay { emptyState(isEmpty: blocks.isEmpty) }
        .sheet(item: $presentedEntry) { entry in
            RawLogSheet(entry: entry)
        }
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if isEmpty {
            if displayedSessions.allSatisfy({ $0.store.rawLogEntries.isEmpty }) {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "terminal",
                    description: Text("Raw zigbee2mqtt log lines will appear here in real time.")
                )
            } else {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    private var displayedSessions: [BridgeSession] {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        if let id = viewModel.bridgeFilter, let session = connected.first(where: { $0.bridgeID == id }) {
            return [session]
        }
        return connected
    }

    private func mergedEntries() -> [BridgeBoundLogEntry] {
        displayedSessions.flatMap { session in
            viewModel.filteredEntries(store: session.store).map {
                BridgeBoundLogEntry(bridgeID: session.bridgeID, bridgeName: session.displayName, entry: $0)
            }
        }
        .sorted { $0.entry.timestamp > $1.entry.timestamp }
    }
}
