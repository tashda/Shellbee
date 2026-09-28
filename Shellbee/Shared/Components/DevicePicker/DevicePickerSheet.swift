import SwiftUI

/// Picks devices from a list: search, type chips, a filled check per row
/// and an inline endpoint picker where it matters. Used by Add Members and
/// Activity's Filter by Device, so both look and behave the same. The
/// selection is drafted locally and only handed back on confirm.
struct DevicePickerSheet: View {
    let title: String
    let items: [DevicePickerItem]
    /// Shown first under `pinnedTitle` (e.g. devices with activity).
    var pinnedIDs: Set<String> = []
    var pinnedTitle = ""
    var showsEndpoints = false
    var confirmTitle: LocalizedStringKey = "Done"
    var emptyTitle = "No Devices"
    var emptyDescription = ""
    /// Item ID → endpoint for every selected device.
    let onConfirm: ([String: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String: Int]
    private let initialSelection: [String: Int]
    @State private var searchText = ""
    @State private var category: Device.Category?

    init(
        title: String,
        items: [DevicePickerItem],
        selection: [String: Int] = [:],
        pinnedIDs: Set<String> = [],
        pinnedTitle: String = "",
        showsEndpoints: Bool = false,
        confirmTitle: LocalizedStringKey = "Done",
        emptyTitle: String = "No Devices",
        emptyDescription: String = "",
        onConfirm: @escaping ([String: Int]) -> Void
    ) {
        self.title = title
        self.items = items.sorted {
            $0.device.friendlyName.localizedCaseInsensitiveCompare($1.device.friendlyName) == .orderedAscending
        }
        self.pinnedIDs = pinnedIDs
        self.pinnedTitle = pinnedTitle
        self.showsEndpoints = showsEndpoints
        self.confirmTitle = confirmTitle
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.onConfirm = onConfirm
        self.initialSelection = selection
        _draft = State(initialValue: selection)
    }

    private var categories: [Device.Category] {
        let present = Set(items.map(\.device.category))
        return Device.Category.allCases.filter(present.contains)
    }

    private var visible: [DevicePickerItem] {
        let tokens = GlobalSearchResults.tokens(in: searchText)
        return items.filter { item in
            (category == nil || item.device.category == category)
                && (tokens.isEmpty || GlobalSearchResults.matches(tokens, in: [
                    item.device.friendlyName, item.device.definition?.vendor,
                    item.device.definition?.model, item.device.definition?.description
                ]))
        }
    }

    private var sections: [(title: String, items: [DevicePickerItem])] {
        let all = visible
        guard !pinnedIDs.isEmpty else { return [("", all)] }
        let pinned = all.filter { pinnedIDs.contains($0.id) }
        let others = all.filter { !pinnedIDs.contains($0.id) }
        return [(pinnedTitle, pinned), ("Other devices", others)].filter { !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Group {
                    if categories.count > 1 {
                        Section {
                            categoryChips
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    ForEach(sections, id: \.title) { section in
                        Section {
                            ForEach(section.items) { row($0) }
                        } header: {
                            if !section.title.isEmpty { Text(section.title) }
                        }
                    }
                }
                .shellbeeThemedRows()
            }
            .listStyle(.insetGrouped)
            .shellbeeThemedCanvas()
            .searchable(text: $searchText, prompt: "Search devices")
            .overlay { emptyState }
            .safeAreaInset(edge: .bottom) { selectionPill }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmToolbarButton(title: confirmTitle) {
                        onConfirm(draft)
                        dismiss()
                    }
                    .disabled(draft == initialSelection)
                }
            }
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ item: DevicePickerItem) -> some View {
        DevicePickerRow(
            item: item,
            isSelected: draft[item.id] != nil,
            showsEndpoints: showsEndpoints,
            endpoint: draft[item.id] ?? item.device.availableEndpoints.first ?? 1,
            onToggle: { toggle(item) },
            onEndpointChange: { draft[item.id] = $0 }
        )
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                SelectableFilterChip(title: "All", isSelected: category == nil) { category = nil }
                ForEach(categories, id: \.self) { item in
                    SelectableFilterChip(title: item.label, isSelected: category == item) {
                        category = category == item ? nil : item
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var selectionPill: some View {
        if !draft.isEmpty {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text("\(draft.count) selected")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Button("Clear") {
                    withAnimation(.snappy) { draft.removeAll() }
                }
                .font(.subheadline)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .glassEffectIfAvailable(in: Capsule())
            .padding(.bottom, DesignTokens.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if items.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "cpu", description: Text(emptyDescription))
        } else if visible.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private func toggle(_ item: DevicePickerItem) {
        withAnimation(.snappy) {
            if draft[item.id] != nil {
                draft.removeValue(forKey: item.id)
            } else {
                draft[item.id] = item.device.availableEndpoints.first ?? 1
            }
        }
    }
}
