import SwiftUI

/// What Home shows beyond the essentials.
///
/// Home answers "is anything wrong" on its own: the bridges, whatever is
/// happening right now, and whatever needs attention. Everything here is
/// something you only look at when you feel like looking, so none of it is
/// on to begin with.
struct HomeSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(HomeCardKind.network.storageKey) private var showsNetwork = false
    @AppStorage(HomeCardKind.linkQuality.storageKey) private var showsLinkQuality = false
    @AppStorage(HomeCardKind.batteries.storageKey) private var showsBatteries = false
    @AppStorage(HomeCardKind.vendors.storageKey) private var showsVendors = false
    @AppStorage(HomeCardKind.bridgeHealth.storageKey) private var showsBridgeHealth = false
    @AppStorage(HomeCardKind.activity.storageKey) private var showsActivity = false
    @AppStorage(HomeCardKind.orderKey) private var cardOrder = ""
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount = HomeSettings.recentEventsCountDefault

    private var order: [HomeCardKind] { HomeCardKind.ordered(cardOrder) }

    var body: some View {
        let previewData = HomeCardPreviewData(environment: environment)
        List {
            SwiftUI.Group {
                Section {
                    ForEach(order) { kind in
                        row(kind, previewData: previewData)
                    }
                    .onMove { source, destination in
                        var moved = order
                        moved.move(fromOffsets: source, toOffset: destination)
                        cardOrder = HomeCardKind.encode(moved)
                    }
                } header: {
                    Text("Cards")
                } footer: {
                    Text("Cards appear on Home in this order, under Needs attention. Drag to reorder.")
                }

                if showsActivity {
                    Section {
                        Picker("Events", selection: $recentEventsCount) {
                            ForEach(HomeSettings.recentEventsOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .tint(.secondary)
                    } header: {
                        Text("Activity")
                    } footer: {
                        Text("How many recent events the card shows before \"See all\".")
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .shellbeeThemedCanvas()
        .navigationTitle("Home Screen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ kind: HomeCardKind, previewData: HomeCardPreviewData) -> some View {
        let isOn = binding(for: kind)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(kind.title)
                    Text(kind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HomeCardPreview(kind: kind, data: previewData)
                .opacity(isOn.wrappedValue ? 1 : DesignTokens.Opacity.disabled)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func binding(for kind: HomeCardKind) -> Binding<Bool> {
        switch kind {
        case .network: $showsNetwork
        case .linkQuality: $showsLinkQuality
        case .batteries: $showsBatteries
        case .vendors: $showsVendors
        case .bridgeHealth: $showsBridgeHealth
        case .activity: $showsActivity
        }
    }
}

#Preview {
    NavigationStack {
        HomeSettingsView()
    }
    .environment(AppEnvironment())
}
