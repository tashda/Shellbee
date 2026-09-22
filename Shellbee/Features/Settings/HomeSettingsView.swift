import SwiftUI

/// What little there is to configure about Home. The card arranging went
/// with the cards: Home is now the bridges, what needs attention, and the
/// last few events, in that order. All that's left to choose is how many
/// events "the last few" means.
struct HomeSettingsView: View {
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount = HomeSettings.recentEventsCountDefault

    var body: some View {
        Form {
            Section {
                Picker("Events", selection: $recentEventsCount) {
                    ForEach(HomeSettings.recentEventsOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("How many recent events Home shows before \"See all\".")
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeSettingsView()
    }
}
