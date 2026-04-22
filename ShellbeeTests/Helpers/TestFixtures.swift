import Foundation
@testable import Shellbee

// MARK: - Raw JSON helpers

extension Data {
    static func json(_ string: String) -> Data {
        Data(string.utf8)
    }
}

// MARK: - Z2M message frame builder

struct Z2MFrame {
    static func make(topic: String, payload: Any) -> Data {
        let envelope: [String: Any] = ["topic": topic, "payload": payload]
        return try! JSONSerialization.data(withJSONObject: envelope)
    }

    static func makeJSON(topic: String, payloadJSON: String) -> Data {
        let raw = #"{"topic":"\#(topic)","payload":\#(payloadJSON)}"#
        return Data(raw.utf8)
    }
}

// MARK: - Device builders

enum DeviceFixture {
    static func light(
        ieee: String = "0x000b57fffec6a5b3",
        name: String = "Living Room Light",
        vendor: String = "IKEA",
        model: String = "LED1545G12",
        colorCapable: Bool = false
    ) -> Device {
        var features: [Expose] = [
            Expose(type: "binary", name: "state", label: "State", description: nil,
                   access: 7, property: "state", endpoint: nil, features: nil, options: nil,
                   unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                   values: nil, valueOn: .string("ON"), valueOff: .string("OFF"), presets: nil),
            Expose(type: "numeric", name: "brightness", label: "Brightness", description: nil,
                   access: 7, property: "brightness", endpoint: nil, features: nil, options: nil,
                   unit: nil, valueMin: 0, valueMax: 254, valueStep: nil,
                   values: nil, valueOn: nil, valueOff: nil, presets: nil),
            Expose(type: "numeric", name: "color_temp", label: "Color temperature", description: nil,
                   access: 7, property: "color_temp", endpoint: nil, features: nil, options: nil,
                   unit: "mired", valueMin: 250, valueMax: 454, valueStep: nil,
                   values: nil, valueOn: nil, valueOff: nil, presets: nil)
        ]
        if colorCapable {
            features.append(Expose(
                type: "composite", name: "color_xy", label: "Color (X/Y)", description: nil,
                access: 7, property: "color", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                values: nil, valueOn: nil, valueOff: nil, presets: nil
            ))
        }
        let lightExpose = Expose(
            type: "light", name: "light", label: "Light", description: nil,
            access: 0, property: nil, endpoint: nil, features: features, options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .router, vendor: vendor, model: model,
                          exposes: [lightExpose], powerSource: "Mains (single phase)")
    }

    static func switchPlug(
        ieee: String = "0x000b57fffec51378",
        name: String = "Kitchen Plug"
    ) -> Device {
        let switchExpose = Expose(
            type: "switch", name: "switch", label: "Switch", description: nil,
            access: 0, property: nil, endpoint: nil,
            features: [Expose(type: "binary", name: "state", label: "State", description: nil,
                              access: 7, property: "state", endpoint: nil, features: nil, options: nil,
                              unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                              values: nil, valueOn: .string("ON"), valueOff: .string("OFF"), presets: nil)],
            options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .router,
                          vendor: "IKEA", model: "E1603",
                          exposes: [switchExpose], powerSource: "Mains (single phase)")
    }

    static func sensor(
        ieee: String = "0x00158d0001234567",
        name: String = "Office Sensor",
        battery: Bool = true
    ) -> Device {
        var exposes: [Expose] = [
            Expose(type: "numeric", name: "temperature", label: "Temperature", description: nil,
                   access: 1, property: "temperature", endpoint: nil, features: nil, options: nil,
                   unit: "°C", valueMin: nil, valueMax: nil, valueStep: nil,
                   values: nil, valueOn: nil, valueOff: nil, presets: nil),
            Expose(type: "numeric", name: "humidity", label: "Humidity", description: nil,
                   access: 1, property: "humidity", endpoint: nil, features: nil, options: nil,
                   unit: "%", valueMin: 0, valueMax: 100, valueStep: nil,
                   values: nil, valueOn: nil, valueOff: nil, presets: nil)
        ]
        if battery {
            exposes.append(Expose(
                type: "numeric", name: "battery", label: "Battery", description: nil,
                access: 1, property: "battery", endpoint: nil, features: nil, options: nil,
                unit: "%", valueMin: 0, valueMax: 100, valueStep: nil,
                values: nil, valueOn: nil, valueOff: nil, presets: nil
            ))
        }
        return makeDevice(ieee: ieee, name: name, type: .endDevice,
                          vendor: "Aqara", model: "WSDCGQ11LM",
                          exposes: exposes, powerSource: "Battery")
    }

    static func climate(
        ieee: String = "0x0015bc001e000fe0",
        name: String = "Bedroom Thermostat"
    ) -> Device {
        let climateExpose = Expose(
            type: "climate", name: "climate", label: "Climate", description: nil,
            access: 0, property: nil, endpoint: nil,
            features: [
                Expose(type: "numeric", name: "local_temperature",
                       label: "Local temperature", description: nil,
                       access: 1, property: "local_temperature", endpoint: nil, features: nil, options: nil,
                       unit: "°C", valueMin: 0, valueMax: 40, valueStep: nil,
                       values: nil, valueOn: nil, valueOff: nil, presets: nil),
                Expose(type: "numeric", name: "occupied_heating_setpoint",
                       label: "Occupied heating setpoint", description: nil,
                       access: 7, property: "occupied_heating_setpoint", endpoint: nil, features: nil, options: nil,
                       unit: "°C", valueMin: 5, valueMax: 30, valueStep: 0.5,
                       values: nil, valueOn: nil, valueOff: nil, presets: nil),
                Expose(type: "enum", name: "system_mode", label: "System mode", description: nil,
                       access: 7, property: "system_mode", endpoint: nil, features: nil, options: nil,
                       unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                       values: ["off", "auto", "heat"],
                       valueOn: nil, valueOff: nil, presets: nil)
            ],
            options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .endDevice,
                          vendor: "Eurotronic", model: "SPZB0001",
                          exposes: [climateExpose], powerSource: "Battery")
    }

    static func cover(
        ieee: String = "0x0c4314fffed23456",
        name: String = "Living Room Blinds"
    ) -> Device {
        let coverExpose = Expose(
            type: "cover", name: "cover", label: "Cover", description: nil,
            access: 0, property: nil, endpoint: nil,
            features: [
                Expose(type: "enum", name: "state", label: "State", description: nil,
                       access: 7, property: "state", endpoint: nil, features: nil, options: nil,
                       unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                       values: ["OPEN", "CLOSE", "STOP"],
                       valueOn: nil, valueOff: nil, presets: nil),
                Expose(type: "numeric", name: "position", label: "Position", description: nil,
                       access: 7, property: "position", endpoint: nil, features: nil, options: nil,
                       unit: "%", valueMin: 0, valueMax: 100, valueStep: nil,
                       values: nil, valueOn: nil, valueOff: nil, presets: nil)
            ],
            options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .endDevice,
                          vendor: "SOMFY", model: "1241752",
                          exposes: [coverExpose], powerSource: "Mains (single phase)")
    }

    static func lock(
        ieee: String = "0x54ef441000130bed",
        name: String = "Front Door Lock"
    ) -> Device {
        let lockExpose = Expose(
            type: "lock", name: "lock", label: "Lock", description: nil,
            access: 0, property: nil, endpoint: nil,
            features: [
                Expose(type: "enum", name: "state", label: "State", description: nil,
                       access: 7, property: "state", endpoint: nil, features: nil, options: nil,
                       unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                       values: ["LOCK", "UNLOCK"],
                       valueOn: nil, valueOff: nil, presets: nil)
            ],
            options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .endDevice,
                          vendor: "Nuki", model: "nuki_2_0",
                          exposes: [lockExpose], powerSource: "Battery")
    }

    static func fan(
        ieee: String = "0x0c4314fffeb1c2d3",
        name: String = "Bathroom Fan"
    ) -> Device {
        let fanExpose = Expose(
            type: "fan", name: "fan", label: "Fan", description: nil,
            access: 0, property: nil, endpoint: nil,
            features: [
                Expose(type: "binary", name: "state", label: "State", description: nil,
                       access: 7, property: "state", endpoint: nil, features: nil, options: nil,
                       unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                       values: nil, valueOn: .string("ON"), valueOff: .string("OFF"), presets: nil),
                Expose(type: "enum", name: "mode", label: "Mode", description: nil,
                       access: 7, property: "mode", endpoint: nil, features: nil, options: nil,
                       unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
                       values: ["off", "low", "medium", "high", "auto"],
                       valueOn: nil, valueOff: nil, presets: nil)
            ],
            options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: nil, valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .router,
                          vendor: "Itho", model: "RB01D",
                          exposes: [fanExpose], powerSource: "Mains (single phase)")
    }

    static func remote(
        ieee: String = "0x000b57fffe9a0b01",
        name: String = "TRADFRI Remote"
    ) -> Device {
        let actionExpose = Expose(
            type: "enum", name: "action", label: "Action", description: nil,
            access: 1, property: "action", endpoint: nil, features: nil, options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil,
            values: ["toggle", "brightness_up_click", "brightness_down_click"],
            valueOn: nil, valueOff: nil, presets: nil
        )
        return makeDevice(ieee: ieee, name: name, type: .endDevice,
                          vendor: "IKEA", model: "E1524/E1810",
                          exposes: [actionExpose], powerSource: "Battery")
    }

    static func coordinator() -> Device {
        makeDevice(ieee: "0x00124b0000000000", name: "Coordinator", type: .coordinator,
                   vendor: nil, model: nil, exposes: [], powerSource: "Mains (single phase)")
    }

    static var allCategoryDevices: [Device] {
        [light(), light(ieee: "0x0017880103f72892", name: "Bedroom Hue", colorCapable: true),
         switchPlug(), sensor(), climate(), cover(), lock(), fan(), remote()]
    }

    // MARK: - Private

    private static func makeDevice(
        ieee: String, name: String, type: DeviceType,
        vendor: String?, model: String?,
        exposes: [Expose], powerSource: String
    ) -> Device {
        let definition: DeviceDefinition? = (vendor != nil || model != nil) ?
            DeviceDefinition(
                model: model ?? "", vendor: vendor ?? "",
                description: "", supportsOTA: false,
                exposes: exposes, options: nil, icon: nil
            ) : nil

        return Device(
            ieeeAddress: ieee, type: type, networkAddress: Int.random(in: 10000...60000),
            supported: true, friendlyName: name, disabled: false,
            description: nil, definition: definition,
            powerSource: powerSource, modelId: model,
            manufacturer: vendor, interviewCompleted: true, interviewing: false,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
    }
}

// MARK: - State builders

enum StateFixture {
    static func lightOn(brightness: Int = 200, colorTemp: Int = 370, lqi: Int = 142) -> [String: JSONValue] {
        [
            "state": .string("ON"),
            "brightness": .int(brightness),
            "color_temp": .int(colorTemp),
            "linkquality": .int(lqi)
        ]
    }

    static func lightOff() -> [String: JSONValue] {
        ["state": .string("OFF"), "brightness": .int(0), "linkquality": .int(100)]
    }

    static func batteryLow(level: Int = 15) -> [String: JSONValue] {
        ["battery": .int(level), "linkquality": .int(100)]
    }

    static func weakSignal(lqi: Int = 20) -> [String: JSONValue] {
        ["battery": .int(80), "linkquality": .int(lqi)]
    }

    static func withOTA(state: String = "available",
                        installed: Int = 1,
                        latest: Int = 2) -> [String: JSONValue] {
        [
            "update": .object([
                "state": .string(state),
                "installed_version": .int(installed),
                "latest_version": .int(latest),
                "progress": state == "updating" ? .double(50.0) : .null
            ]),
            "linkquality": .int(100)
        ]
    }

    static func climate(localTemp: Double = 20.5, setpoint: Double = 22.0,
                        mode: String = "heat") -> [String: JSONValue] {
        [
            "local_temperature": .double(localTemp),
            "occupied_heating_setpoint": .double(setpoint),
            "system_mode": .string(mode),
            "linkquality": .int(45)
        ]
    }

    static func sensor(temp: Double = 21.5, humidity: Double = 65.2,
                       battery: Int = 75) -> [String: JSONValue] {
        [
            "temperature": .double(temp),
            "humidity": .double(humidity),
            "battery": .int(battery),
            "linkquality": .int(98)
        ]
    }
}

// MARK: - Z2M WebSocket frame builders

enum FrameFixture {
    static var bridgeOnline: Data {
        Z2MFrame.make(topic: "bridge/state", payload: "online")
    }

    static var bridgeOffline: Data {
        Z2MFrame.make(topic: "bridge/state", payload: "offline")
    }

    static func bridgeDevices(_ devices: [Device]) -> Data {
        let json = try! JSONEncoder().encode(devices)
        let arr = try! JSONSerialization.jsonObject(with: json)
        return Z2MFrame.make(topic: "bridge/devices", payload: arr)
    }

    static func deviceState(name: String, state: [String: JSONValue]) -> Data {
        let json = try! JSONEncoder().encode(state)
        let obj = try! JSONSerialization.jsonObject(with: json)
        return Z2MFrame.make(topic: name, payload: obj)
    }

    static func availability(name: String, online: Bool) -> Data {
        Z2MFrame.make(topic: "\(name)/availability", payload: ["state": online ? "online" : "offline"])
    }

    static func logMessage(level: String = "info", message: String, namespace: String? = nil) -> Data {
        var payload: [String: Any] = ["level": level, "message": message, "message_id": NSNull()]
        if let ns = namespace { payload["namespace"] = ns }
        return Z2MFrame.make(topic: "bridge/logging", payload: payload)
    }

    static func bridgeEvent(type: String, friendlyName: String) -> Data {
        let payload: [String: Any] = [
            "type": type,
            "data": ["friendly_name": friendlyName, "ieee_address": "0x00158d0001234567"]
        ]
        return Z2MFrame.make(topic: "bridge/event", payload: payload)
    }

    static func otaUpdateResponse(deviceName: String, status: String = "ok") -> Data {
        let payload: [String: Any] = ["status": status, "data": ["id": deviceName]]
        return Z2MFrame.make(topic: "bridge/response/device/ota_update/update", payload: payload)
    }

    static func otaCheckResponse(deviceName: String, status: String = "ok") -> Data {
        let payload: [String: Any] = ["status": status, "data": ["id": deviceName]]
        return Z2MFrame.make(topic: "bridge/response/device/ota_update/check", payload: payload)
    }

    static func bridgeResponse(topic: String, data: [String: Any] = [:]) -> Data {
        let payload: [String: Any] = ["status": "ok", "data": data]
        return Z2MFrame.make(topic: topic, payload: payload)
    }
}
