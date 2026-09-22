import SwiftUI

/// The Activity Center's raw log: zigbee2mqtt lines in minute cards, with
/// the same frame as the Activity feed. Tapping a line opens it in a sheet.
struct RawLogFeedView: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: BridgeLogViewModel
    let selection: Binding<LogsPaneRoute?>?
    @State private var presentedEntry: PresentedEntry?
    @State private var liveFeed = LiveFeedState<RawLogBlock>()

    init(viewModel: BridgeLogViewModel, selection: Binding<LogsPaneRoute?>? = nil) {
        self.viewModel = viewModel
        self.selection = selection
    }

    var body: some View {
        let liveBlocks = RawLogBlock.blocks(from: mergedEntries())
        let blocks = liveFeed.displayedItems(from: liveBlocks)
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(LiveFeedAnchor.top)
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
                                open(item)
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
            .simultaneousGesture(DragGesture(minimumDistance: DesignTokens.Spacing.xs).onChanged { _ in
                liveFeed.beginReadingHistory(with: liveBlocks)
            })
            .overlay(alignment: .bottom) {
                if liveFeed.isReadingHistory {
                    FollowLiveButton {
                        withAnimation(.smooth) {
                            liveFeed.followLive()
                            proxy.scrollTo(LiveFeedAnchor.top, anchor: .top)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay { emptyState(isEmpty: blocks.isEmpty) }
        .sheet(item: $presentedEntry) { presented in
            RawLogSheet(entry: presented.route.entry)
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

    private func open(_ item: BridgeBoundLogEntry) {
        let route = LogRoute(bridgeID: item.bridgeID, entry: item.entry)
        if let selection {
            selection.wrappedValue = .bridge(route)
        } else {
            presentedEntry = PresentedEntry(route: route)
        }
    }

    private struct PresentedEntry: Identifiable {
        let route: LogRoute
        var id: UUID { route.entry.id }
    }
}
