import Foundation

/// A capability the Device Library can filter a type by, read from the
/// entry's exposes. Each type offers only the ones that tell its models
/// apart ("Color" for lights, "Tilt" for covers).
enum DocLibraryFeature: String, CaseIterable, Identifiable {
    case color
    case whiteSpectrum
    case dimmableOnly
    case effects
    case temperature
    case humidity
    case occupancy
    case contact
    case waterLeak
    case illuminance
    case airQuality
    case smoke
    case energy
    case tilt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color: "Color"
        case .whiteSpectrum: "White spectrum"
        case .dimmableOnly: "Dimmable only"
        case .effects: "Effects"
        case .temperature: "Temperature"
        case .humidity: "Humidity"
        case .occupancy: "Occupancy"
        case .contact: "Contact"
        case .waterLeak: "Water leak"
        case .illuminance: "Illuminance"
        case .airQuality: "Air quality"
        case .smoke: "Smoke"
        case .energy: "Energy monitoring"
        case .tilt: "Tilt"
        }
    }

    var systemImage: String {
        switch self {
        case .color: "paintpalette"
        case .whiteSpectrum: "thermometer.sun"
        case .dimmableOnly: "sun.min"
        case .effects: "sparkles"
        case .temperature: "thermometer.medium"
        case .humidity: "humidity"
        case .occupancy: "figure.walk.motion"
        case .contact: "door.left.hand.open"
        case .waterLeak: "drop.triangle"
        case .illuminance: "sun.max"
        case .airQuality: "aqi.medium"
        case .smoke: "smoke"
        case .energy: "bolt"
        case .tilt: "blinds.vertical.open"
        }
    }

    /// The features worth offering for a slice of the library.
    static func features(for type: DocDeviceType?) -> [DocLibraryFeature] {
        switch type {
        case .light: [.color, .whiteSpectrum, .dimmableOnly, .effects]
        case .sensor: [.temperature, .humidity, .occupancy, .contact, .waterLeak, .illuminance, .airQuality, .smoke]
        case .switch_: [.energy]
        case .cover: [.tilt]
        case .thermostat, .remote, .energy, nil: []
        }
    }

    func matches(_ entry: DocBrowserEntry) -> Bool {
        let exposes = Set(entry.exposes)
        let hasColor = exposes.contains("light.color_xy") || exposes.contains("light.color_hs")
        switch self {
        case .color: return hasColor
        case .whiteSpectrum: return exposes.contains("light.color_temp")
        case .dimmableOnly:
            return exposes.contains("light.brightness") && !hasColor && !exposes.contains("light.color_temp")
        case .effects: return exposes.contains("effect") || exposes.contains { $0.hasPrefix("effect_") }
        case .temperature: return exposes.contains("temperature")
        case .humidity: return exposes.contains("humidity")
        case .occupancy: return exposes.contains("occupancy") || exposes.contains("presence")
        case .contact: return exposes.contains("contact")
        case .waterLeak: return exposes.contains("water_leak")
        case .illuminance: return exposes.contains("illuminance")
        case .airQuality: return !exposes.isDisjoint(with: ["co2", "voc", "voc_index", "pm25", "formaldehyd"])
        case .smoke: return exposes.contains("smoke")
        case .energy: return exposes.contains("power") || exposes.contains("energy")
        case .tilt: return exposes.contains("cover.tilt")
        }
    }
}

/// The Device Library's filters: power source, features (all must match)
/// and whether to show only models already in the network.
struct DocLibraryFilters: Equatable {
    enum Power: Hashable { case any, battery, mains }

    var power: Power = .any
    var features: Set<DocLibraryFeature> = []
    var inNetworkOnly = false

    var isActive: Bool { power != .any || !features.isEmpty || inNetworkOnly }

    func matches(_ entry: DocBrowserEntry, owned: [String: Int]) -> Bool {
        switch power {
        case .any: break
        case .battery: guard entry.isBatteryPowered else { return false }
        case .mains: guard !entry.isBatteryPowered else { return false }
        }
        if inNetworkOnly, owned[entry.ownershipKey] == nil { return false }
        return features.allSatisfy { $0.matches(entry) }
    }

    var powerTitle: String? {
        switch power {
        case .any: nil
        case .battery: "Battery"
        case .mains: "Mains / USB"
        }
    }
}
