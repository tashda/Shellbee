import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

enum HomeCardID: String, CaseIterable, Codable, Identifiable, Hashable, Transferable {
    case bridge
    case devices
    case groups
    case mesh
    case recentEvents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bridge:        "Bridge"
        case .devices:       "Devices"
        case .groups:        "Groups"
        case .mesh:          "Mesh"
        case .recentEvents:  "Recent Events"
        }
    }

    var symbol: String {
        switch self {
        case .bridge:        "antenna.radiowaves.left.and.right"
        case .devices:       "sensor.tag.radiowaves.forward.fill"
        case .groups:        "rectangle.3.group.fill"
        case .mesh:          "point.3.connected.trianglepath.dotted"
        case .recentEvents:  "list.bullet.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bridge:        .teal
        case .devices:       .orange
        case .groups:        .green
        case .mesh:          .indigo
        case .recentEvents:  .blue
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@Observable
final class HomeLayoutStore {
    private(set) var visibleOrder: [HomeCardID]
    private(set) var hidden: Set<HomeCardID>
    var isEditing = false

    private static let visibleKey = "homeVisibleOrder"
    private static let hiddenKey  = "homeHiddenCards"
    private static let initializedKey = "homeLayoutInitialized"
    private static let defaultHidden: Set<HomeCardID> = [.groups]

    init() {
        let defaults = UserDefaults.standard
        let isInitialized = defaults.bool(forKey: Self.initializedKey)

        let savedVisible = Self.decode(defaults.string(forKey: Self.visibleKey))
        var savedHidden  = Set(Self.decode(defaults.string(forKey: Self.hiddenKey)))

        if !isInitialized {
            savedHidden.formUnion(Self.defaultHidden)
            defaults.set(true, forKey: Self.initializedKey)
        }

        var visible = savedVisible
        for card in HomeCardID.allCases where !visible.contains(card) && !savedHidden.contains(card) {
            visible.append(card)
        }

        self.visibleOrder = visible
        self.hidden = savedHidden
    }

    func hide(_ card: HomeCardID) {
        visibleOrder.removeAll { $0 == card }
        hidden.insert(card)
        persist()
    }

    func show(_ card: HomeCardID) {
        hidden.remove(card)
        if !visibleOrder.contains(card) {
            visibleOrder.append(card)
        }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        visibleOrder.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func move(_ card: HomeCardID, before target: HomeCardID) {
        guard card != target,
              let fromIndex = visibleOrder.firstIndex(of: card),
              let toIndex = visibleOrder.firstIndex(of: target) else { return }
        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        visibleOrder.move(fromOffsets: IndexSet([fromIndex]), toOffset: destination)
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(visibleOrder.map(\.rawValue).joined(separator: ","), forKey: Self.visibleKey)
        defaults.set(hidden.map(\.rawValue).sorted().joined(separator: ","), forKey: Self.hiddenKey)
    }

    private static func decode(_ raw: String?) -> [HomeCardID] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").compactMap { HomeCardID(rawValue: String($0)) }
    }
}
