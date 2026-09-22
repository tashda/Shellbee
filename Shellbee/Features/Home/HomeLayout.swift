import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// Home is three cards, named for what the user owns rather than for
/// Zigbee2MQTT's object model: the plumbing, their things, what happened.
/// Bridge and Mesh were the same subject told twice; Groups is a way of
/// addressing devices they already have.
enum HomeCardID: String, CaseIterable, Codable, Identifiable, Hashable, Transferable {
    case network
    case devices
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:  "Network"
        case .devices:  "Devices"
        case .activity: "Activity"
        }
    }

    var symbol: String {
        switch self {
        case .network:  "antenna.radiowaves.left.and.right"
        case .devices:  "sensor.tag.radiowaves.forward.fill"
        case .activity: "list.bullet.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .network:  .teal
        case .devices:  .orange
        case .activity: .blue
        }
    }

    /// Resolves an id persisted by a pre-merge build. Bridge and Mesh both
    /// became Network, Groups folded into Devices, Recent Events became
    /// Activity.
    static func migratingVisible(_ raw: String) -> HomeCardID? {
        switch raw {
        case "bridge", "mesh":  .network
        case "groups":          .devices
        case "recentEvents":    .activity
        default:                HomeCardID(rawValue: raw)
        }
    }

    /// The same mapping for the *hidden* set, except that an absorbed card is
    /// dropped rather than mapped: someone who hid Groups (the old default)
    /// did not ask to lose the whole Devices card.
    static func migratingHidden(_ raw: String) -> HomeCardID? {
        switch raw {
        case "bridge":        .network
        case "recentEvents":  .activity
        case "mesh", "groups": nil
        default:              HomeCardID(rawValue: raw)
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
    private static let mergedCardsMigrationKey = "homeMergedCardsMigrationV1"

    init() {
        let defaults = UserDefaults.standard
        let isInitialized = defaults.bool(forKey: Self.initializedKey)

        let savedVisible = Self.decodeVisible(defaults.string(forKey: Self.visibleKey))
        let savedHidden = Set(Self.decodeHidden(defaults.string(forKey: Self.hiddenKey)))

        if !isInitialized {
            defaults.set(true, forKey: Self.initializedKey)
        }

        // One-time migration for layouts saved before the cards merged. The
        // decode above already folded the old ids; this only records that the
        // fold happened and rewrites the stored strings so the legacy values
        // don't get re-parsed on every launch.
        let needsMergeMigration = !defaults.bool(forKey: Self.mergedCardsMigrationKey)

        var visible = savedVisible
        for card in HomeCardID.allCases where !visible.contains(card) && !savedHidden.contains(card) {
            visible.append(card)
        }

        self.visibleOrder = visible
        self.hidden = savedHidden

        if needsMergeMigration {
            defaults.set(true, forKey: Self.mergedCardsMigrationKey)
            persist()
        }
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

    /// Decodes the visible order, folding legacy ids and dropping the
    /// duplicates that folding creates (bridge + mesh both became network).
    private static func decodeVisible(_ raw: String?) -> [HomeCardID] {
        guard let raw, !raw.isEmpty else { return [] }
        var seen: Set<HomeCardID> = []
        return raw.split(separator: ",")
            .compactMap { HomeCardID.migratingVisible(String($0)) }
            .filter { seen.insert($0).inserted }
    }

    private static func decodeHidden(_ raw: String?) -> [HomeCardID] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").compactMap { HomeCardID.migratingHidden(String($0)) }
    }
}
