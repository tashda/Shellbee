import SwiftUI

/// The Activity Center's feed: events stacked by subject like Notification
/// Center, with errors and warnings pinned under Needs Attention. Tapping a
/// stack expands it in place; tapping an event opens its log in a sheet.
struct ActivityFeedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: LogsViewModel
    let selection: Binding<LogsPaneRoute?>?
    @State private var expandedStackID: String?
    @State private var presentedEntry: PresentedEntry?
    @State private var showsClearAttentionConfirmation = false
    @State private var liveFeed = LiveFeedState<ActivityFeedSection>()
    @AppStorage(ActivityAttentionClearance.storageKey) private var clearanceRaw = ""

    init(viewModel: LogsViewModel, selection: Binding<LogsPaneRoute?>? = nil) {
        self.viewModel = viewModel
        self.selection = selection
    }

    var body: some View {
        let liveSections = feedSections()
        let sections = liveFeed.displayedItems(from: liveSections)
        // A feed with a single subject, such as one opened from a device's
        // Show All Logs, lists every event instead of one collapsed stack.
        let isSingleStack = sections.count == 1 && sections[0].stacks.count == 1
        ScrollView {
            Color.clear
                .frame(height: 0)
                .id(LiveFeedAnchor.top)
            LazyVStack(alignment: .leading, spacing: DesignTokens.ActivityFeed.cardSpacing) {
                ForEach(sections) { section in
                    if sections.count > 1 || section.kind == .needsAttention {
                        sectionHeader(section)
                    }
                    ForEach(section.stacks) { stack in
                        if isSingleStack {
                            entryCards(stack)
                        } else {
                            stackView(stack)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.ActivityFeed.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .modifier(LiveFeedScrollTracking(state: liveFeed, liveItems: liveSections))
        .toolbar {
            FollowLiveToolbarContent(isVisible: liveFeed.isReadingHistory) {
                liveFeed.requestReturnToLive()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: viewModel.filterSignature) {
            liveFeed.followLive()
        }
        .overlay { emptyState(isEmpty: sections.isEmpty) }
        .animation(.smooth, value: expandedStackID)
        .sheet(item: $presentedEntry) { presented in
            ActivityLogSheet(route: presented.route)
        }
        .confirmationDialog(
            "Clear Needs Attention?",
            isPresented: $showsClearAttentionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                let bridgeIDs = Set(feedSections()
                    .first(where: { $0.kind == .needsAttention })?
                    .stacks
                    .map(\.bridgeID) ?? [])
                updateClearance { $0.clear(bridgeIDs: bridgeIDs) }
            }
        } message: {
            Text("These events will move to Recent. No log data is deleted.")
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ section: ActivityFeedSection) -> some View {
        HStack {
            Text(section.kind == .needsAttention ? "Needs Attention" : "Recent")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if section.kind == .needsAttention {
                Button {
                    showsClearAttentionConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear Needs Attention")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.top, section.kind == .recent ? DesignTokens.ActivityFeed.sectionSpacing : 0)
    }

    /// Clearing moves the events down into Recent; nothing is deleted.
    private func updateClearance(_ change: (inout ActivityAttentionClearance) -> Void) {
        var clearance = ActivityAttentionClearance(rawValue: clearanceRaw)
        change(&clearance)
        withAnimation(.smooth) {
            clearanceRaw = clearance.rawValue
        }
    }

    @ViewBuilder
    private func stackView(_ stack: ActivityStack) -> some View {
        let bridgeName = environment.registry.session(for: stack.bridgeID)?.displayName ?? "Bridge"
        if expandedStackID == stack.id {
            expandedHeader(ActivityCardContent(entry: stack.latest, subject: stack.subject, bridgeName: bridgeName).title)
            entryCards(stack)
        } else {
            Button {
                if stack.isStacked {
                    expandedStackID = stack.id
                } else {
                    open(stack.latest, bridgeID: stack.bridgeID)
                }
            } label: {
                ActivityStackCard(
                    stack: stack,
                    content: ActivityCardContent(entry: stack.latest, subject: stack.subject, bridgeName: bridgeName)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                if stack.section == .needsAttention {
                    Button("Clear", systemImage: "xmark") {
                        updateClearance { $0.clear(stack) }
                    }
                }
                Button("Copy Message", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = stack.latest.message
                }
            }
        }
    }

    private func entryCards(_ stack: ActivityStack) -> some View {
        let bridgeName = environment.registry.session(for: stack.bridgeID)?.displayName ?? "Bridge"
        return ForEach(stack.entries) { entry in
            Button {
                open(entry, bridgeID: stack.bridgeID)
            } label: {
                ActivityCard(
                    entry: entry,
                    content: ActivityCardContent(entry: entry, subject: stack.subject, bridgeName: bridgeName)
                )
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func expandedHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Button("Show Less") {
                expandedStackID = nil
            }
            .font(.subheadline.weight(.semibold))
            .glassButtonStyleIfAvailable()
        }
        .padding(.leading, DesignTokens.Spacing.xs)
        .padding(.top, DesignTokens.Spacing.sm)
    }

    private func open(_ entry: LogEntry, bridgeID: UUID) {
        let route = LogRoute(bridgeID: bridgeID, entry: entry)
        if let selection {
            selection.wrappedValue = .activity(route)
        } else {
            presentedEntry = PresentedEntry(route: route)
        }
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if isEmpty {
            if environment.allLogEntries.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "tray",
                    description: Text("Events appear here as your bridges report them.")
                )
            } else if !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView(
                    "No Matching Activity",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try changing your filters.")
                )
            }
        }
    }

    // MARK: - Data

    private func feedSections() -> [ActivityFeedSection] {
        let sessions = environment.registry.orderedSessions.filter { session in
            session.isConnected && (viewModel.bridgeFilter.map { $0 == session.bridgeID } ?? true)
        }
        let entries = sessions.flatMap { session in
            viewModel.filteredEntries(store: session.store, coalescing: false)
                .map { BridgeBoundLogEntry(bridgeID: session.bridgeID, bridgeName: session.displayName, entry: $0) }
        }
        .sorted { $0.entry.timestamp > $1.entry.timestamp }

        return ActivityStackBuilder.sections(
            from: entries,
            clearance: ActivityAttentionClearance(rawValue: clearanceRaw),
            subject: environment.activitySubject(for:)
        )
    }

    private struct PresentedEntry: Identifiable {
        let route: LogRoute
        var id: UUID { route.entry.id }
    }
}
