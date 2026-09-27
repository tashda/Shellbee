import Foundation

/// A slice of the Device Library: the models already in the user's network,
/// every entry, one device type, or one manufacturer.
enum DocLibraryScope: Hashable, Identifiable {
    case owned
    case all
    case type(DocDeviceType)
    case other
    case vendor(String)

    var id: Self { self }

    var title: String {
        switch self {
        case .owned: "In your network"
        case .all: "All devices"
        case .type(let type): type.pluralTitle
        case .other: "Other"
        case .vendor(let vendor): vendor
        }
    }

    var systemImage: String {
        switch self {
        case .owned: "house"
        case .all: "square.grid.2x2"
        case .type(let type): type.systemImage
        case .other: "questionmark.square.dashed"
        case .vendor: "building.2"
        }
    }

    /// Entries in this slice. `owned` holds the model keys of devices on any
    /// connected bridge.
    func entries(from all: [DocBrowserEntry], owned: [String: Int]) -> [DocBrowserEntry] {
        switch self {
        case .owned: all.filter { owned[$0.ownershipKey] != nil }
        case .all: all
        case .type(let type): all.filter { $0.deviceType == type }
        case .other: all.filter { $0.deviceType == nil }
        case .vendor(let vendor): all.filter { $0.vendor == vendor }
        }
    }

    /// A manufacturer's page groups by type; every other slice groups by
    /// manufacturer.
    var groupsByType: Bool {
        if case .vendor = self { return true }
        return false
    }
}

extension DocBrowserEntry {
    /// Matches a paired device's definition to its library entry.
    var ownershipKey: String { Self.ownershipKey(vendor: vendor, model: model) }

    static func ownershipKey(vendor: String, model: String) -> String {
        "\(vendor.lowercased())|\(model.lowercased())"
    }
}

extension AppEnvironment {
    /// How many devices of each library model are paired across connected
    /// bridges, keyed by `DocBrowserEntry.ownershipKey`.
    var ownedLibraryModels: [String: Int] {
        allDevices.reduce(into: [:]) { counts, item in
            guard let definition = item.device.definition else { return }
            counts[DocBrowserEntry.ownershipKey(vendor: definition.vendor, model: definition.model), default: 0] += 1
        }
    }
}
