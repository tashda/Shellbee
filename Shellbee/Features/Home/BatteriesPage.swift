import SwiftUI

/// Every battery-powered device, grouped by what to do about it: replace
/// now, silent (probably flat), soon, and fine. Opened from the Batteries
/// card. Tapping a device opens its battery sheet.
struct BatteriesPage: View {
    let readings: [HomeDeviceReading]

    @State private var filter: BatteryUrgency?
    @State private var searchText = ""
    @State private var selected: HomeDeviceReading?
    @State private var openedDevice: DeviceRoute?

    private var batteries: [HomeDeviceReading] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return readings
            .filter { $0.battery != nil }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { ($0.battery ?? 0, $0.name) < ($1.battery ?? 0, $1.name) }
    }

    private var sections: [(urgency: BatteryUrgency, readings: [HomeDeviceReading])] {
        BatteryUrgency.allCases
            .filter { filter == nil || filter == $0 }
            .compactMap { urgency in
                let matching = batteries.filter { $0.batteryUrgency == urgency }
                return matching.isEmpty ? nil : (urgency, matching)
            }
    }

    var body: some View {
        List {
            SwiftUI.Group {
                Section {
                    filterChips
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(sections, id: \.urgency) { section in
                    Section {
                        ForEach(section.readings) { reading in
                            Button { selected = reading } label: {
                                HomeDeviceReadingRow(
                                    reading: reading,
                                    value: "\(reading.battery ?? 0) %",
                                    valueStyle: AnyShapeStyle(.status(reading.battery?.batteryTone ?? .poor)),
                                    detail: seenText(reading)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(section.urgency.title) · \(section.readings.count)")
                    } footer: {
                        Text(section.urgency.footnote)
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .shellbeeThemedCanvas()
        .searchable(text: $searchText, prompt: "Search devices")
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Batteries")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { reading in
            BatteryQuickSheet(reading: reading) { openedDevice = $0 }
        }
        .navigationDestination(item: $openedDevice) { route in
            DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
        }
    }

    private var filterChips: some View {
        GlassChipRow {
            SelectableFilterChip(title: "All", isSelected: filter == nil) { filter = nil }
            ForEach(BatteryUrgency.allCases) { urgency in
                SelectableFilterChip(title: urgency.title, isSelected: filter == urgency) {
                    filter = filter == urgency ? nil : urgency
                }
            }
        }
    }

    private func seenText(_ reading: HomeDeviceReading) -> String {
        guard let lastSeen = reading.lastSeen else { return reading.device.cardSubtitle }
        return "Seen \(lastSeen.formatted(.relative(presentation: .named)))"
    }
}
