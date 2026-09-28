import SwiftUI

/// The cards you can put on Home. None of them are on by default: Home
/// answers "is anything wrong" on its own, and these answer the questions
/// you only ask when you feel like looking.
///
/// They render under Needs attention, in the order set in Settings › Home
/// Screen (this declaration order until the user drags them).
enum HomeCardKind: String, CaseIterable, Identifiable, Sendable {
    case network
    case linkQuality
    case batteries
    case vendors
    case bridgeHealth
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:      "Network"
        case .linkQuality:  "Link quality"
        case .batteries:    "Batteries"
        case .vendors:      "Vendors"
        case .bridgeHealth: "Bridge health"
        case .activity:     "Activity"
        }
    }

    /// One line in the settings row saying what the card is for.
    var summary: String {
        switch self {
        case .network:      "Devices, routers and end devices"
        case .linkQuality:  "How well the mesh is connected"
        case .batteries:    "Which batteries are going flat"
        case .vendors:      "Who made your network"
        case .bridgeHealth: "Uptime, memory and messages"
        case .activity:     "The last few events, as on the Activity tab"
        }
    }

    var symbol: String {
        switch self {
        case .network:      "chart.bar.doc.horizontal"
        case .linkQuality:  "chart.bar.fill"
        case .batteries:    "battery.50"
        case .vendors:      "building.2"
        case .bridgeHealth: "heart.text.square"
        case .activity:     "list.bullet.rectangle"
        }
    }

    var storageKey: String { "homeCard.\(rawValue).enabled" }

    /// Comma-separated raw values in the user's order.
    static let orderKey = "homeCards.order"

    /// Every card in the stored order; cards missing from it (new ones, or
    /// none stored yet) follow in declaration order.
    static func ordered(_ stored: String) -> [HomeCardKind] {
        let listed = stored.split(separator: ",").compactMap { HomeCardKind(rawValue: String($0)) }
        var seen = Set<HomeCardKind>()
        let unique = listed.filter { seen.insert($0).inserted }
        return unique + allCases.filter { !seen.contains($0) }
    }

    static func encode(_ order: [HomeCardKind]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }
}
