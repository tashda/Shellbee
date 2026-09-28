import SwiftUI

/// Every measured device by link quality, weakest first, grouped into the
/// same ranges as the Home card, with range chips and search like the
/// Batteries page. Opened from the card's ↗.
struct LinkQualityPage: View {
    let readings: [HomeDeviceReading]

    @Environment(AppEnvironment.self) private var environment
    @State private var range: String?
    @State private var searchText = ""

    private static let edges = [0, 50, 100, 150, 200]

    private var sections: [(title: String, readings: [HomeDeviceReading])] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let measured = readings
            .filter { ($0.linkQuality ?? 0) > 0 }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { ($0.linkQuality ?? 0, $0.name) < ($1.linkQuality ?? 0, $1.name) }
        return Self.edges.enumerated().compactMap { index, lower in
            let upper = index + 1 < Self.edges.count ? Self.edges[index + 1] : nil
            let inRange = measured.filter { reading in
                let value = reading.linkQuality ?? 0
                return value >= lower && upper.map { value < $0 } ?? true
            }
            guard !inRange.isEmpty else { return nil }
            let title = upper.map { "\(lower)–\($0)" } ?? "\(lower)+"
            return (title, inRange)
        }
    }

    var body: some View {
        let all = sections
        let shown = all.filter { range == nil || $0.title == range }
        List {
            SwiftUI.Group {
                if all.count > 1 {
                    Section {
                        GlassChipRow {
                            SelectableFilterChip(title: "All", isSelected: range == nil) { range = nil }
                            ForEach(all, id: \.title) { section in
                                SelectableFilterChip(title: section.title, isSelected: range == section.title) {
                                    range = range == section.title ? nil : section.title
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                ForEach(shown, id: \.title) { section in
                    Section("\(section.title) · \(section.readings.count)") {
                        ForEach(section.readings) { reading in
                            NavigationLink(value: reading.route) {
                                HomeDeviceReadingRow(
                                    reading: reading,
                                    value: "\(reading.linkQuality ?? 0)",
                                    valueStyle: AnyShapeStyle(.status(reading.linkQuality?.lqiTone ?? .poor))
                                )
                            }
                        }
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .shellbeeThemedCanvas()
        .searchable(text: $searchText, prompt: "Search devices")
        .overlay {
            if !searchText.isEmpty && shown.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if shown.isEmpty, environment.isLoading(.devices) {
                LoadingStateView(title: "Loading devices")
            } else if shown.isEmpty {
                ContentUnavailableView(
                    "No Signal Readings",
                    systemImage: "wifi",
                    description: Text("Devices report link quality when they send a message.")
                )
            }
        }
        .navigationTitle("Link Quality")
        .navigationBarTitleDisplayMode(.inline)
    }
}
