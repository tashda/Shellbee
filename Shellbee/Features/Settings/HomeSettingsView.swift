import SwiftUI

/// What Home shows beyond the essentials.
///
/// Home answers "is anything wrong" on its own: the bridges, whatever is
/// happening right now, and whatever needs attention. Everything here is
/// something you only look at when you feel like looking, so none of it is
/// on to begin with.
struct HomeSettingsView: View {
    @AppStorage(HomeCardKind.network.storageKey) private var showsNetwork = false
    @AppStorage(HomeCardKind.linkQuality.storageKey) private var showsLinkQuality = false
    @AppStorage(HomeCardKind.batteries.storageKey) private var showsBatteries = false
    @AppStorage(HomeCardKind.vendors.storageKey) private var showsVendors = false
    @AppStorage(HomeCardKind.bridgeHealth.storageKey) private var showsBridgeHealth = false
    @AppStorage(HomeCardKind.activity.storageKey) private var showsActivity = false
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount = HomeSettings.recentEventsCountDefault

    var body: some View {
        Form {
            Section {
                toggle(.network, isOn: $showsNetwork)
                toggle(.linkQuality, isOn: $showsLinkQuality)
                toggle(.batteries, isOn: $showsBatteries)
                toggle(.vendors, isOn: $showsVendors)
                toggle(.bridgeHealth, isOn: $showsBridgeHealth)
                toggle(.activity, isOn: $showsActivity)
            } header: {
                Text("Cards")
            } footer: {
                Text("Cards appear on Home in this order, under Needs attention.")
            }

            if showsActivity {
                Section {
                    Picker("Events", selection: $recentEventsCount) {
                        ForEach(HomeSettings.recentEventsOptions, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                } header: {
                    Text("Activity")
                } footer: {
                    Text("How many recent events the card shows before \"See all\".")
                }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ kind: HomeCardKind, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(kind.title)
                Text(kind.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeSettingsView()
    }
}
