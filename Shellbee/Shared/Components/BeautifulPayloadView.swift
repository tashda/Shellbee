import SwiftUI

struct BeautifulPayloadView: View {
    let payload: [String: JSONValue]
    var device: Device? = nil

    private static let deviceCardKeys: Set<String> = [
        "linkquality", "battery", "power_source", "device_type", "device", "last_seen"
    ]
    private static let lightKeys: Set<String> = [
        "state", "brightness", "color_temp", "color_mode", "color", "color_xy", "color_hs", "effect"
    ]
    private static let readingKeys: Set<String> = [
        "temperature", "humidity", "pressure", "co2", "voc_index", "eco2", "tvoc",
        "pm25", "illuminance", "illuminance_lux", "device_temperature",
        "soil_moisture", "current", "voltage", "power", "energy", "noise"
    ]
    private static let eventKeys: Set<String> = ["action", "click", "hold", "gesture"]
    private static let settingsKeys: Set<String> = [
        "power_on_behavior", "occupancy_timeout", "transition",
        "temperature_calibration", "humidity_calibration", "keep_time"
    ]
    private static let objectSectionNames: [String: String] = [
        "update": "Firmware",
        "color_options": "Color Settings",
        "ballast_config": "Ballast",
        "preset": "Preset",
    ]
    private static let firmwareKeyOrder = [
        "installed_version", "latest_version", "state", "latest_release_notes", "latest_source"
    ]
    private static let firmwareKeyLabels: [String: String] = [
        "installed_version":    "Installed Version",
        "latest_version":       "Latest Version",
        "state":                "Status",
        "latest_release_notes": "Release Notes",
        "latest_source":        "Source",
    ]

    private var isLight: Bool {
        guard let device else { return false }
        return LightControlContext(device: device, state: payload) != nil
    }

    private func exposeLabel(for key: String) -> String? {
        func search(_ exposes: [Expose]) -> String? {
            for expose in exposes {
                if expose.property == key || expose.name == key { return expose.label }
                if let found = search(expose.features ?? []) { return found }
            }
            return nil
        }
        return search(device?.definition?.exposes ?? [])
    }

    private func exposeUnit(for key: String) -> String? {
        func search(_ exposes: [Expose]) -> String? {
            for expose in exposes {
                if expose.property == key || expose.name == key { return expose.unit }
                if let found = search(expose.features ?? []) { return found }
            }
            return nil
        }
        return search(device?.definition?.exposes ?? [])
    }

    private static func humanize(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var sections: [(title: String, items: [(label: String, value: JSONValue, unit: String?)])] {
        var skip = Self.deviceCardKeys
        if isLight { skip.formUnion(Self.lightKeys) }

        var readings: [(String, JSONValue, String?)] = []
        var events:   [(String, JSONValue, String?)] = []
        var settings: [(String, JSONValue, String?)] = []
        var state:    [(String, JSONValue, String?)] = []
        var objects: [(title: String, items: [(String, JSONValue, String?)])] = []

        for (key, value) in payload.sorted(by: { $0.key < $1.key }) {
            guard !skip.contains(key) else { continue }
            if case .null = value { continue }

            if case .object(let nested) = value {
                let title  = Self.objectSectionNames[key] ?? Self.humanize(key)
                let labels = key == "update" ? Self.firmwareKeyLabels : [:]
                let order  = key == "update" ? Self.firmwareKeyOrder  : []
                let items: [(String, JSONValue, String?)] = nested
                    .filter { if case .null = $0.value { return false }; return true }
                    .sorted {
                        let ai = order.firstIndex(of: $0.key) ?? Int.max
                        let bi = order.firstIndex(of: $1.key) ?? Int.max
                        return ai != bi ? ai < bi : $0.key < $1.key
                    }
                    .map { (labels[$0.key] ?? Self.humanize($0.key), $0.value, nil) }
                if !items.isEmpty { objects.append((title: title, items: items)) }
            } else {
                let lbl  = exposeLabel(for: key) ?? Self.humanize(key)
                let unit = exposeUnit(for: key)
                if      Self.readingKeys.contains(key)  { readings.append((lbl, value, unit)) }
                else if Self.eventKeys.contains(key)    { events.append((lbl, value, unit)) }
                else if Self.settingsKeys.contains(key) { settings.append((lbl, value, unit)) }
                else                                    { state.append((lbl, value, unit)) }
            }
        }

        var result: [(title: String, items: [(String, JSONValue, String?)])] = []
        for (title, items) in [("Readings", readings), ("Events", events), ("Settings", settings), ("State", state)] {
            if !items.isEmpty { result.append((title: title, items: items)) }
        }
        if result.count == 1, result[0].title != "Readings" { result[0].title = "State" }
        result.append(contentsOf: objects)
        return result.map { section in
            (title: section.title, items: section.items.map { (label: $0.0, value: $0.1, unit: $0.2) })
        }
    }

    var body: some View {
        let allSections = sections
        if !allSections.isEmpty {
            ForEach(allSections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.label) { item in
                        BeautifulRow(label: item.label, value: item.value, unit: item.unit)
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        BeautifulPayloadView(
            payload: [
                "temperature": .double(21.5),
                "humidity": .double(65.0),
                "battery": .int(72),
                "linkquality": .int(120),
                "power_on_behavior": .string("on"),
                "update": .object([
                    "installed_version": .int(65554),
                    "latest_version":    .int(65554),
                    "state":             .string("idle"),
                ]),
                "color_options": .object(["execute_if_off": .bool(false)])
            ],
            device: nil
        )
    }
}
