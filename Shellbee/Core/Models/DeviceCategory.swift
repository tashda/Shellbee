import Foundation

extension Device {
    enum Category: String, CaseIterable, Sendable, Hashable {
        case light, switchPlug, sensor, climate, cover, lock, fan, remote, other

        var label: String {
            switch self {
            case .light:      return "Lights"
            case .switchPlug: return "Switches & Plugs"
            case .sensor:     return "Sensors"
            case .climate:    return "Climate"
            case .cover:      return "Covers"
            case .lock:       return "Locks"
            case .fan:        return "Fans"
            case .remote:     return "Remotes"
            case .other:      return "Other"
            }
        }

        var systemImage: String {
            switch self {
            case .light:      return "lightbulb.fill"
            case .switchPlug: return "power"
            case .sensor:     return "sensor.fill"
            case .climate:    return "thermometer.medium"
            case .cover:      return "blinds.horizontal.closed"
            case .lock:       return "lock.fill"
            case .fan:        return "fan.fill"
            case .remote:     return "command"
            case .other:      return "cpu"
            }
        }
    }

    var category: Category {
        guard let exposes = definition?.exposes else { return .remote }
        let types = exposes.map(\.type)
        if types.contains("light")   { return .light }
        if types.contains("switch")  { return .switchPlug }
        if types.contains("climate") { return .climate }
        if types.contains("cover")   { return .cover }
        if types.contains("lock")    { return .lock }
        if types.contains("fan")     { return .fan }
        if exposes.contains(where: { $0.name == "action" }) { return .remote }
        if exposes.contains(where: { $0.type == "numeric" || $0.type == "binary" }) { return .sensor }
        return .other
    }

    var categorySystemImage: String { category.systemImage }
}
