import SwiftUI

/// The Activity Center's feed: events stacked by subject like Notification
/// Center, with errors and warnings pinned under Needs Attention. Tapping a
/// stack expands it in place; tapping an event opens its log in a sheet.
struct ActivityFeedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: LogsViewModel
    @State private var expandedStackID: String?
    @State private var presentedEntry: PresentedEntry?

    var body: some View {
        let sections = feedSections()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.ActivityFeed.cardSpacing) {
                ForEach(sections) { section in
                    if sections.count > 1 {
                        sectionHeader(section.kind)
                    }
                    ForEach(section.stacks) { stack in
                        stackView(stack)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.ActivityFeed.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .overlay { emptyState(isEmpty: sections.isEmpty) }
        .animation(.smooth, value: expandedStackID)
        .sheet(item: $presentedEntry) { presented in
            ActivityLogSheet(route: presented.route)
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ kind: ActivityFeedSection.Kind) -> some View {
        Text(kind == .needsAttention ? "Needs Attention" : "Recent")
            .font(.title3.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.top, kind == .recent ? DesignTokens.ActivityFeed.sectionSpacing : 0)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func stackView(_ stack: ActivityStack) -> some View {
        let store = environment.registry.session(for: stack.bridgeID)?.store
        let bridgeName = environment.registry.session(for: stack.bridgeID)?.displayName ?? "Bridge"
        if expandedStackID == stack.id {
            expandedHeader(ActivityCardContent(entry: stack.latest, subject: stack.subject, bridgeName: bridgeName).title)
            ForEach(stack.entries) { entry in
                Button {
                    presentedEntry = PresentedEntry(route: LogRoute(bridgeID: stack.bridgeID, entry: entry))
                } label: {
                    ActivityCard(
                        entry: entry,
                        content: ActivityCardContent(entry: entry, subject: stack.subject, bridgeName: bridgeName),
                        store: store
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } else {
            Button {
                if stack.isStacked {
                    expandedStackID = stack.id
                } else {
                    presentedEntry = PresentedEntry(route: LogRoute(bridgeID: stack.bridgeID, entry: stack.latest))
                }
            } label: {
                ActivityStackCard(
                    stack: stack,
                    content: ActivityCardContent(entry: stack.latest, subject: stack.subject, bridgeName: bridgeName),
                    store: store
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Copy Message", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = stack.latest.message
                }
            }
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
            viewModel.filteredEntries(store: session.store)
                .map { BridgeBoundLogEntry(bridgeID: session.bridgeID, bridgeName: session.displayName, entry: $0) }
        }
        .sorted { $0.entry.timestamp > $1.entry.timestamp }

        return ActivityStackBuilder.sections(from: entries) { item in
            guard let store = environment.registry.session(for: item.bridgeID)?.store,
                  let name = LogRowIconography.subjectName(for: item.entry, in: store) else { return .bridge }
            return .named(name)
        }
    }

    private struct PresentedEntry: Identifiable {
        let route: LogRoute
        var id: UUID { route.entry.id }
    }
}
