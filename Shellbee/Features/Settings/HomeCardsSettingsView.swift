import SwiftUI

struct HomeCardsSettingsView: View {
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount = HomeSettings.recentEventsCountDefault
    @AppStorage(HomeSettings.cardDisplayKey(.bridge)) private var bridgeCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.devices)) private var devicesCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.groups)) private var groupsCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.mesh)) private var meshCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.recentEvents)) private var recentEventsCardDisplayRaw = HomeCardDisplayMode.one.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Recent Events", selection: $recentEventsCount) {
                    ForEach(HomeSettings.recentEventsOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            } header: {
                Text("Content")
            }

            Section {
                displayPicker("Bridges", selection: $bridgeCardDisplayRaw)
                displayPicker("Devices", selection: $devicesCardDisplayRaw)
                displayPicker("Groups", selection: $groupsCardDisplayRaw)
                displayPicker("Mesh", selection: $meshCardDisplayRaw)
                displayPicker("Recent Events", selection: $recentEventsCardDisplayRaw)
            } header: {
                Text("Card Layout")
            }

            Section("Preview") {
                HomeCardsPreview(
                    recentEventsCount: recentEventsCount,
                    displayModes: displayModes
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Home Cards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayModes: [HomeCardID: HomeCardDisplayMode] {
        [
            .bridge: displayMode(for: bridgeCardDisplayRaw),
            .devices: displayMode(for: devicesCardDisplayRaw),
            .groups: displayMode(for: groupsCardDisplayRaw),
            .mesh: displayMode(for: meshCardDisplayRaw),
            .recentEvents: displayMode(for: recentEventsCardDisplayRaw)
        ]
    }

    private func displayPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(HomeCardDisplayMode.allCases, id: \.rawValue) { mode in
                Text(mode.label).tag(mode.rawValue)
            }
        }
    }

    private func displayMode(for value: String) -> HomeCardDisplayMode {
        HomeCardDisplayMode(rawValue: value) ?? .one
    }
}

private struct HomeCardsPreview: View {
    let recentEventsCount: Int
    let displayModes: [HomeCardID: HomeCardDisplayMode]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(HomeCardID.allCases) { card in
                if displayModes[card] == .perBridge {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        HomeCardPreviewTile(card: card, subtitle: "Home")
                        HomeCardPreviewTile(card: card, subtitle: "Studio")
                    }
                } else {
                    HomeCardPreviewTile(card: card, subtitle: subtitle(for: card))
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func subtitle(for card: HomeCardID) -> String {
        switch card {
        case .recentEvents: "Last \(recentEventsCount) events"
        default: "All bridges"
        }
    }
}

private struct HomeCardPreviewTile: View {
    let card: HomeCardID
    let subtitle: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            FeatureIconTile(symbol: card.symbol, tint: card.tint, size: DesignTokens.Size.settingsIconFrame)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        HomeCardsSettingsView()
    }
}
