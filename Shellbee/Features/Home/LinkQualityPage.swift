import SwiftUI

/// Every measured device by link quality, weakest first, grouped into the
/// same ranges as the Home card. Opened from the card's ↗.
struct LinkQualityPage: View {
    let readings: [HomeDeviceReading]

    private static let edges = [0, 50, 100, 150, 200]

    private var sections: [(title: String, readings: [HomeDeviceReading])] {
        let measured = readings
            .filter { ($0.linkQuality ?? 0) > 0 }
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
        List {
            SwiftUI.Group {
                ForEach(sections, id: \.title) { section in
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
        .overlay {
            if sections.isEmpty {
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
