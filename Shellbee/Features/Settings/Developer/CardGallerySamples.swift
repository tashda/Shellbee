import SwiftUI

/// Fixture-backed examples for the developer Card Gallery. These definitions
/// deliberately use the same expose shapes as Z2M, so the gallery exercises
/// the real control contexts and the real settings-section grouping.
struct CardGallerySample: Identifiable {
    let id: String
    let title: String
    let detail: String
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    /// A plausible "what changed" fixture for the Log Detail surface, in the
    /// same shape the real Activity sheet renders beneath the compact card.
    let logChangeRows: [LogChangeRow]

    init(
        _ id: String,
        _ title: String,
        _ detail: String,
        device: Device,
        state: [String: JSONValue],
        isAvailable: Bool = true,
        logChangeRows: [LogChangeRow] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.device = device
        self.state = state
        self.isAvailable = isAvailable
        self.logChangeRows = logChangeRows
    }
}

/// A card as it appears in the gallery's picker. Device samples remain
/// separate from the group fixture because their detail pages are genuinely
/// different surfaces.
struct CardGalleryPreview: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let sample: CardGallerySample?

    static func device(_ sample: CardGallerySample) -> CardGalleryPreview {
        CardGalleryPreview(
            id: sample.id,
            title: sample.device.category.label,
            detail: sample.title,
            symbol: sample.device.category.systemImage,
            sample: sample
        )
    }

    static let group = CardGalleryPreview(
        id: "group",
        title: "Group",
        detail: "Gallery Group",
        symbol: "rectangle.3.group",
        sample: nil
    )
}

enum CardGalleryCatalog {
    static let samples: [CardGallerySample] = [
        light,
        switchPlug,
        sensor,
        climate,
        cover,
        lock,
        fan,
        remote,
        other
    ]

    static let group = Group(
        id: 208,
        friendlyName: "Gallery Group",
        description: "Living room lights",
        members: [
            GroupMember(ieeeAddress: light.device.ieeeAddress, endpoint: 1),
            GroupMember(ieeeAddress: "0xgallery-light-2", endpoint: 1),
            GroupMember(ieeeAddress: switchPlug.device.ieeeAddress, endpoint: 1)
        ],
        scenes: [Z2MScene(id: 1, name: "Relax"), Z2MScene(id: 2, name: "Bright")]
    )

    static let groupMembers: [Device] = [light.device, light.device, switchPlug.device]

    static let groupState: [String: JSONValue] = [
        "state": .string("ON"), "brightness": .int(168), "color_mode": .string("color_temp"),
        "color_temp": .int(320), "linkquality": .int(124)
    ]

    static let previews = samples.map { CardGalleryPreview.device($0) } + [.group]

    private static func device(
        _ id: String,
        name: String,
        type: DeviceType = .router,
        model: String,
        vendor: String,
        description: String,
        exposes: [Expose],
        state: [String: JSONValue],
        powerSource: String = "mains",
        available: Bool = true,
        logChangeRows: [LogChangeRow] = []
    ) -> CardGallerySample {
        let device = Device(
            ieeeAddress: "0xgallery(id)",
            type: type,
            networkAddress: 42,
            supported: true,
            friendlyName: name,
            disabled: false,
            definition: DeviceDefinition(
                model: model,
                vendor: vendor,
                description: description,
                supportsOTA: false,
                exposes: exposes,
                options: nil,
                icon: nil
            ),
            powerSource: powerSource,
            modelId: model,
            manufacturer: vendor,
            interviewCompleted: true,
            interviewing: false
        )
        return CardGallerySample(
            id, name, description, device: device, state: state, isAvailable: available,
            logChangeRows: logChangeRows
        )
    }

    private static func expose(
        _ type: String,
        _ name: String,
        property: String? = nil,
        access: Int = 1,
        label: String? = nil,
        unit: String? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        values: [String]? = nil,
        on: JSONValue? = nil,
        off: JSONValue? = nil,
        features: [Expose]? = nil,
        category: String? = nil
    ) -> Expose {
        Expose(
            type: type,
            name: name,
            label: label ?? name.replacingOccurrences(of: "_", with: " ").capitalized,
            description: nil,
            access: access,
            property: property ?? name,
            endpoint: nil,
            features: features,
            options: nil,
            unit: unit,
            valueMin: min,
            valueMax: max,
            valueStep: step,
            values: values,
            valueOn: on,
            valueOff: off,
            presets: nil,
            category: category
        )
    }

    private static let state = expose("binary", "state", access: 3, on: .string("ON"), off: .string("OFF"))

    static let light = device(
        "light", name: "Gallery Light", model: "LCT010", vendor: "Philips",
        description: "Hue White and Color Ambiance", exposes: [
            expose("light", "light", access: 1, features: [
                state,
                expose("numeric", "brightness", access: 3, unit: "%", min: 0, max: 254, step: 1),
                expose("numeric", "color_temp", access: 3, unit: "mired", min: 153, max: 500, step: 1),
                expose("composite", "color_xy", property: "color", access: 3),
                expose("enum", "power_on_behavior", access: 3, values: ["off", "on", "previous"]),
                expose("numeric", "color_temp_startup", access: 3, unit: "mired", min: 153, max: 500, step: 1)
            ])
        ], state: [
            "state": .string("ON"), "brightness": .int(190), "color_mode": .string("color_temp"),
            "color_temp": .int(280), "power_on_behavior": .string("previous"), "color_temp_startup": .int(370),
            "linkquality": .int(132)
        ], logChangeRows: [
            LogChangeRow(id: "brightness", label: "Brightness", value: .text(from: "60 %", to: "75 %")),
            LogChangeRow(id: "colour", label: "Colour", value: .colour(
                from: Color(hue: 0.08, saturation: 0.7, brightness: 1),
                to: Color(hue: 0.55, saturation: 0.55, brightness: 1),
                name: "Ocean"
            ))
        ]
    )

    static let switchPlug = device(
        "switch", name: "Gallery Plug", model: "SPZB0001", vendor: "Shellbee Labs",
        description: "Smart plug", exposes: [
            expose("switch", "switch", features: [state]),
            expose("numeric", "power", unit: "W"),
            expose("numeric", "energy", unit: "kWh"),
            expose("numeric", "voltage", unit: "V"),
            expose("numeric", "current", unit: "A"),
            expose("enum", "power_on_behavior", access: 3, values: ["off", "on", "previous"])
        ], state: [
            "state": .string("ON"), "power": .double(12.4), "energy": .double(3.21),
            "voltage": .double(231), "current": .double(0.05), "power_on_behavior": .string("previous"),
            "linkquality": .int(118)
        ], logChangeRows: [
            LogChangeRow(id: "state", label: "State", value: .text(from: "Off", to: "On"))
        ]
    )

    static let sensor = device(
        "sensor", name: "Gallery Sensor", type: .endDevice, model: "ZG-204ZV", vendor: "HOBEIAN",
        description: "Millimeter wave motion detection", exposes: [
            expose("binary", "presence"),
            expose("numeric", "illuminance", unit: "lx"),
            expose("numeric", "temperature", unit: "°C"),
            expose("numeric", "humidity", unit: "%"),
            expose("enum", "temperature_unit", access: 3, values: ["celsius", "fahrenheit"]),
            expose("numeric", "fading_time", access: 3, unit: "s", min: 0, max: 300, step: 1),
            expose("binary", "indicator", access: 3, on: .string("ON"), off: .string("OFF")),
            expose("numeric", "device_temperature", unit: "°C", category: "diagnostic"),
            expose("numeric", "battery", unit: "%", category: "diagnostic")
        ], state: [
            "presence": .bool(true), "illuminance": .int(21), "temperature": .double(21.4),
            "humidity": .double(48), "temperature_unit": .string("celsius"), "fading_time": .int(30),
            "indicator": .string("ON"), "device_temperature": .double(38), "battery": .int(76),
            "linkquality": .int(94)
        ], powerSource: "battery", logChangeRows: [
            LogChangeRow(id: "presence", label: "Presence", value: .text(from: "No", to: "Yes")),
            LogChangeRow(id: "illuminance", label: "Illuminance", value: .text(from: "8 lx", to: "21 lx"))
        ]
    )

    static let climate = device(
        "climate", name: "Gallery Thermostat", model: "TRV001", vendor: "Shellbee Labs",
        description: "Radiator thermostat", exposes: [
            expose("climate", "climate", features: [
                expose("numeric", "local_temperature", unit: "°C"),
                expose("numeric", "occupied_heating_setpoint", access: 3, unit: "°C", min: 5, max: 35, step: 0.5),
                expose("enum", "system_mode", access: 3, values: ["off", "heat", "auto"]),
                expose("enum", "running_state", values: ["idle", "heating"]),
                expose("enum", "preset", access: 3, values: ["none", "away", "eco"])
            ])
        ], state: [
            "local_temperature": .double(21.5), "occupied_heating_setpoint": .double(22),
            "system_mode": .string("heat"), "running_state": .string("heating"), "preset": .string("none"),
            "linkquality": .int(105)
        ], logChangeRows: [
            LogChangeRow(id: "occupied_heating_setpoint", label: "Target", value: .text(from: "20.5 °C", to: "22 °C"))
        ]
    )

    static let cover = device(
        "cover", name: "Gallery Blind", model: "TS130F", vendor: "Tuya",
        description: "Motorized blind", exposes: [
            expose("cover", "cover", features: [
                expose("enum", "state", access: 3, values: ["OPEN", "CLOSE", "STOP", "OPENING", "CLOSING"]),
                expose("numeric", "position", access: 3, unit: "%", min: 0, max: 100, step: 1),
                expose("numeric", "tilt", access: 3, unit: "%", min: 0, max: 100, step: 1),
                expose("binary", "child_lock", access: 3, on: .bool(true), off: .bool(false))
            ])
        ], state: [
            "state": .string("OPEN"), "position": .int(64), "tilt": .int(35), "child_lock": .bool(false),
            "linkquality": .int(86)
        ], logChangeRows: [
            LogChangeRow(id: "position", label: "Position", value: .text(from: "20 %", to: "64 %"))
        ]
    )

    static let lock = device(
        "lock", name: "Gallery Lock", type: .endDevice, model: "LOCK001", vendor: "Shellbee Labs",
        description: "Front door lock", exposes: [
            expose("lock", "lock", features: [
                expose("enum", "state", access: 3, values: ["LOCK", "UNLOCK"]),
                expose("numeric", "auto_relock_time", access: 3, unit: "s", min: 0, max: 60, step: 1),
                expose("enum", "sound_volume", access: 3, values: ["low", "high"])
            ]),
            expose("numeric", "battery", unit: "%", category: "diagnostic")
        ], state: [
            "state": .string("LOCK"), "auto_relock_time": .int(30), "sound_volume": .string("low"),
            "battery": .int(82), "linkquality": .int(78)
        ], powerSource: "battery", logChangeRows: [
            LogChangeRow(id: "state", label: "State", value: .text(from: "Unlocked", to: "Locked"))
        ]
    )

    static let fan = device(
        "fan", name: "Gallery Air Purifier", model: "FAN001", vendor: "Shellbee Labs",
        description: "Air purifier", exposes: [
            expose("fan", "fan", features: [
                state,
                expose("enum", "fan_mode", access: 3, values: ["auto", "low", "medium", "high"]),
                expose("numeric", "fan_speed_percent", access: 3, unit: "%", min: 0, max: 100, step: 1)
            ]),
            expose("numeric", "pm25", unit: "µg/m³"),
            expose("enum", "air_quality", values: ["excellent", "good", "poor"]),
            expose("numeric", "filter_age", unit: "days")
        ], state: [
            "state": .string("ON"), "fan_mode": .string("auto"), "fan_speed_percent": .int(45),
            "pm25": .int(9), "air_quality": .string("excellent"), "filter_age": .int(42),
            "linkquality": .int(110)
        ], logChangeRows: [
            LogChangeRow(id: "fan_speed_percent", label: "Speed", value: .text(from: "20 %", to: "45 %"))
        ]
    )

    static let remote = device(
        "remote", name: "Gallery Remote", type: .endDevice, model: "REMOTE001", vendor: "Shellbee Labs",
        description: "Scene remote", exposes: [
            expose("enum", "action", values: ["brightness_up_click", "brightness_down_click", "toggle"]),
            expose("numeric", "voltage", unit: "mV", category: "diagnostic")
        ], state: [
            "action": .string("brightness_up_click"), "voltage": .int(3045), "linkquality": .int(72)
        ], powerSource: "battery", logChangeRows: [
            LogChangeRow(id: "action", label: "Action", value: .text(from: "Toggle", to: "Brightness Up Click"))
        ]
    )

    static let other = device(
        "other", name: "Gallery Custom Device", model: "CUSTOM001", vendor: "Shellbee Labs",
        description: "Custom Z2M device", exposes: [
            expose("enum", "indicator_mode", access: 3, values: ["off", "on"]),
            expose("text", "custom_label", access: 3)
        ], state: [
            "indicator_mode": .string("on"), "custom_label": .string("Gallery value"),
            "linkquality": .int(64)
        ], logChangeRows: [
            LogChangeRow(id: "indicator_mode", label: "Indicator Mode", value: .text(from: "Off", to: "On"))
        ]
    )
}
